package CpuItem;
my (%fake_data,$type);

sub get {
	eval $start if $b_log;
	($type) = @_;
	my $rows = [];
	if ($type eq 'short' || $type eq 'basic'){
		# note, for short form, just return the raw data, not the processed output
		my $cpu = short_data();
		if ($type eq 'basic'){
			short_output($rows,$cpu);
		}
		else {
			$rows = $cpu;
		}
	}
	else {
		full_output($rows);
	}
	eval $end if $b_log;
	return $rows;
}

## OUTPUT HANDLERS ##
sub full_output {
	eval $start if $b_log;
	my $rows = $_[0];
	my $num = 0;
	my ($b_speeds,$core_speeds_value,$cpu);
	my $sleep = $cpu_sleep * 1000000;
	if (my $file = $system_files{'proc-cpuinfo'}){
		$cpu = cpuinfo_data($file);
	}
	elsif ($bsd_type){
		my ($key1,$val1) = ('','');
		if ($alerts{'sysctl'}){
			if ($alerts{'sysctl'}->{'action'} eq 'use'){
# 				$key1 = 'Status';
# 				$val1 = main::message('dev');
				$cpu = sysctl_data();
			}
			else {
				$key1 = ucfirst($alerts{'sysctl'}->{'action'});
				$val1 = $alerts{'sysctl'}->{'message'};
				@$rows = ({main::key($num++,0,1,$key1) => $val1});
				return;
			}
		}
	}
	my $properties = cpu_properties($cpu);
	my $type = ($properties->{'cpu-type'}) ? $properties->{'cpu-type'}: '';
	my $j = scalar @$rows;
	$cpu->{'model_name'} ||= 'N/A'; 
	push(@$rows, {
	main::key($num++,1,1,'Info') => $properties->{'topology-string'},
	main::key($num++,0,2,'model') => $cpu->{'model_name'},
	},);
	if ($cpu->{'system-cpus'}){
		my %system_cpus = %{$cpu->{'system-cpus'}};
		my $i = 1;
		my $counter = (%system_cpus && scalar keys %system_cpus > 1) ? '-' : '';
		foreach my $key (keys %system_cpus){
			$counter = '-' . $i++ if $counter;
			$rows->[$j]{main::key($num++,0,2,'variant'.$counter)} = $key;
		}
	}
	if ($b_admin && $properties->{'socket'}){
		if ($properties->{'upgrade'}){
			$rows->[$j]{main::key($num++,1,2,'socket')} = $properties->{'socket'} . ' (' . $properties->{'upgrade'} . ')';
			$rows->[$j]{main::key($num++,0,3,'note')} = main::message('note-check');
		}
		else {
			$rows->[$j]{main::key($num++,0,2,'socket')} = $properties->{'socket'};
		}
	}
	$properties->{'bits-sys'} ||= 'N/A';
	$rows->[$j]{main::key($num++,0,2,'bits')} = $properties->{'bits-sys'};
	if ($type){
		$rows->[$j]{main::key($num++,0,2,'type')} = $type;
		if (!$properties->{'topology-full'} && $cpu->{'smt'} && ($extra > 2 || 
		 ($extra > 0 && $cpu->{'smt'} eq 'disabled'))){
			$rows->[$j]{main::key($num++,0,2,'smt')} = $cpu->{'smt'};
		}
	}
	if ($extra > 0){
		$cpu->{'arch'} ||= 'N/A';
		$rows->[$j]{main::key($num++,1,2,'arch')} = $cpu->{'arch'};
		if ($cpu->{'arch-note'}){
			$rows->[$j]{main::key($num++,0,3,'note')} = $cpu->{'arch-note'};
		}
		if ($b_admin && $cpu->{'gen'}){
			$rows->[$j]{main::key($num++,0,3,'gen')} = $cpu->{'gen'};
		}
		if ($b_admin && $properties->{'arch-level'}){
			$rows->[$j]{main::key($num++,1,2,'level')} = $properties->{'arch-level'}[0];
			if ($properties->{'arch-level'}[1]){
				$rows->[$j]{main::key($num++,0,3,'note')} = $properties->{'arch-level'}[1];
			}
		}
		if ($b_admin){
			if ($cpu->{'year'}){
				$rows->[$j]{main::key($num++,0,2,'built')} = $cpu->{'year'};
			}
			if ($cpu->{'process'}){
				$rows->[$j]{main::key($num++,0,2,'process')} = $cpu->{'process'};
			}
		}
		# note: had if arch, but stepping can be defined where arch failed, stepping can be 0
		if (!$b_admin && (defined $cpu->{'stepping'} || defined $cpu->{'revision'})){
			my $rev = main::get_defined($cpu->{'stepping'},$cpu->{'revision'});
			$rows->[$j]{main::key($num++,0,2,'rev')} = $rev;
		}
	}
	if ($b_admin){
		$rows->[$j]{main::key($num++,0,2,'family')} = hex_and_decimal($cpu->{'family'});
		$rows->[$j]{main::key($num++,0,2,'model-id')} = hex_and_decimal($cpu->{'model-id'});
		if (defined $cpu->{'stepping'}){
			$rows->[$j]{main::key($num++,0,2,'stepping')} = hex_and_decimal($cpu->{'stepping'});
		}
		elsif (defined $cpu->{'revision'}){
			$rows->[$j]{main::key($num++,0,2,'rev')} = $cpu->{'revision'};
		}
		if (!%risc && $cpu->{'type'} ne 'elbrus'){
			$cpu->{'microcode'} = ($cpu->{'microcode'}) ? '0x' . $cpu->{'microcode'} :  'N/A';
			$rows->[$j]{main::key($num++,0,2,'microcode')} = $cpu->{'microcode'};
		}
	}
	# note, risc cpus are using l1, L2, L3 more often, but if risc and no L2, skip
	if ($properties->{'topology-string'} && (($extra > 1 && 
	 ($properties->{'l1-cache'} || $properties->{'l3-cache'})) || 
	 (!%risc || $properties->{'l2-cache'}) || $properties->{'cache'})){
		full_output_caches($j,$properties,\$num,$rows);
	}
	# all tests already done to load this, admin, etc
	if ($properties->{'topology-full'}){
		$j = scalar @$rows;
		push(@$rows, {
		main::key($num++,1,1,'Topology') => '',
		},);
		my ($id,$var) = (2,'');
		if (scalar @{$properties->{'topology-full'}} > 1){
			$var = 'variant';
			$id = 3;
		}
		foreach my $topo (@{$properties->{'topology-full'}}){
			if ($var){
				$rows->[$j]{main::key($num++,1,2,'variant')} = '';
			}
			my $x = ($size{'max-cols'} == 1 || $output_type ne 'screen') ? '' : 'x';
			$rows->[$j]{main::key($num++,0,$id,'cpus')} = $topo->{'cpus'} . $x;
			$rows->[$j]{main::key($num++,1,$id+1,'cores')} = $topo->{'cores'};
			if ($topo->{'cores-mt'} && $topo->{'cores-st'}){
				$rows->[$j]{main::key($num++,1,$id+2,'mt')} = $topo->{'cores-mt'};
				$rows->[$j]{main::key($num++,0,$id+3,'tpc')} = $topo->{'tpc'};
				$rows->[$j]{main::key($num++,0,$id+2,'st')} = $topo->{'cores-st'};
			}
			elsif ($topo->{'cores-mt'}){
				$rows->[$j]{main::key($num++,0,$id+2,'tpc')} = $topo->{'tpc'};
			}
			if ($topo->{'max'} || $topo->{'min'}){
				my ($freq,$key) = ('','');
				if ($topo->{'max'} && $topo->{'min'}){
					$key = 'min/max';
					$freq = $topo->{'min'} . '/' . $topo->{'max'};
				}
				elsif ($topo->{'max'}){
					$key = 'max';
					$freq = $topo->{'max'};
				}
				else {
					$key = 'min';
					$freq = $topo->{'min'};
				}
				$rows->[$j]{main::key($num++,0,$id+1,$key)} = $freq;
			}
			if ($topo->{'threads'}){
				$rows->[$j]{main::key($num++,0,$id+1,'threads')} = $topo->{'threads'};
			}
			if ($topo->{'dies'}){
				$rows->[$j]{main::key($num++,0,$id+1,'dies')} = $topo->{'dies'};
			}
		}
		$cpu->{'smt'} ||= 'N/A';
		$rows->[$j]{main::key($num++,0,2,'smt')} = $cpu->{'smt'};
		full_output_caches($j,$properties,\$num,$rows);
	}
	my $speeds = $cpu->{'processors'};
	my $core_key = (defined $speeds && scalar @{$speeds} > 1) ? 'cores' : 'core';
	my $speed_key = ($properties->{'speed-key'}) ? $properties->{'speed-key'}: 'Speed';
	my $min_max = ($properties->{'min-max'}) ? $properties->{'min-max'}: 'N/A';
	my $min_max_key = ($properties->{'min-max-key'}) ? $properties->{'min-max-key'}: 'min/max';
	my $speed = '';
	if (!$properties->{'avg-speed-key'}){
		$speed = (defined $properties->{'speed'}) ? $properties->{'speed'}: 'N/A';
	}
	# Aren't able to get per core speeds in BSDs. Why don't they support this?
	if (defined $speeds && @$speeds){
		# only if defined and not 0
		if (grep {$_} @{$speeds}){
			$core_speeds_value = '';
			$b_speeds = 1;
		}
		else {
			my $id = ($bsd_type) ? 'cpu-speeds-bsd' : 'cpu-speeds';
			$core_speeds_value = main::message($id);
		}
	}
	else {
		$core_speeds_value = main::message('cpu-speeds');
	}
	$j = scalar @$rows;
	push(@$rows, {
	main::key($num++,1,1,$speed_key) => $speed,
	});
	if ($properties->{'avg-speed-key'}){
		$rows->[$j]{main::key($num++,0,2,$properties->{'avg-speed-key'})} = $properties->{'speed'};
		if ($extra > 0 && $properties->{'high-speed-key'}){
			$rows->[$j]{main::key($num++,0,2,$properties->{'high-speed-key'})} = $cpu->{'high-freq'};
		}
	}
	$rows->[$j]{main::key($num++,0,2,$min_max_key)} = $min_max;
	if ($extra > 0 && defined $cpu->{'boost'}){
		$rows->[$j]{main::key($num++,0,2,'boost')} = $cpu->{'boost'};
	}
	if ($b_admin && $properties->{'dmi-speed'} && $properties->{'dmi-max-speed'}){
		$rows->[$j]{main::key($num++,0,2,'base/boost')} = $properties->{'dmi-speed'} . '/' . $properties->{'dmi-max-speed'};
	}
	if ($b_admin && ($cpu->{'governor'} || $cpu->{'scaling-driver'})){
		$rows->[$j]{main::key($num++,1,2,'scaling')} = '';
		$cpu->{'driver'} ||= 'N/A';
		$rows->[$j]{main::key($num++,0,3,'driver')} = $cpu->{'scaling-driver'};
		$cpu->{'governor'} ||= 'N/A';
		$rows->[$j]{main::key($num++,0,3,'governor')} = $cpu->{'governor'};
		# only set if different from cpu min/max
		if ($cpu->{'scaling-min-max'} && $cpu->{'scaling-min-max-key'}){
			$rows->[$j]{main::key($num++,0,3,$cpu->{'scaling-min-max-key'})} = $cpu->{'scaling-min-max'};
		}
	}
	if ($extra > 2){
		if ($properties->{'volts'}){
			$rows->[$j]{main::key($num++,0,2,'volts')} = $properties->{'volts'} . ' V';
		}
		if ($properties->{'ext-clock'}){
			$rows->[$j]{main::key($num++,0,2,'ext-clock')} = $properties->{'ext-clock'};
		}
	}
	$rows->[$j]{main::key($num++,1,2,$core_key)} = $core_speeds_value;
	my $i = 1;
	# if say 96 0 speed cores, no need to print all those 0s
	if ($b_speeds){
		foreach (@{$speeds}){
			$rows->[$j]{main::key($num++,0,3,$i++)} = $_;
		}
	}
	if ($extra > 0 && !$bsd_type){
		my $bogomips = ($cpu->{'bogomips'} && 
		 main::is_numeric($cpu->{'bogomips'})) ? int($cpu->{'bogomips'}) : 'N/A';
		$rows->[$j]{main::key($num++,0,2,'bogomips')} = $bogomips;
	}
	if (($extra > 0 && !$show{'cpu-flag'}) || $show{'cpu-flag'}){
		my @flags = ($cpu->{'flags'}) ? split(/\s+/, $cpu->{'flags'}) : ();
		my $flag_key = (%risc || $bsd_type) ? 'Features': 'Flags';
		my $flag = 'N/A';
		if (!$show{'cpu-flag'}){
			if (@flags){
				# failure to read dmesg.boot: dmesg.boot permissions; then short -Cx list flags
				@flags = grep {/^(dmesg.boot|permissions|avx[2-9]?|ht|lm|nx|pae|pni|(sss|ss)e([2-9])?([a-z])?(_[0-9])?|svm|vmx)$/} @flags;
				@flags = map {s/pni/sse3/; $_} @flags if @flags;
				@flags = sort @flags;
			}
			# only ARM has Features, never seen them for MIPS/PPC/SPARC/RISCV, but check
			if ($risc{'arm'} && $flag eq 'N/A'){
				$flag = main::message('arm-cpu-f');
			}
		}
		if (@flags){
			@flags = sort @flags;
			$flag = join(' ', @flags);
		}
		push(@$rows, {
		main::key($num++,0,1,$flag_key) => $flag,
		},);
	}
	if ($b_admin){
		my $value = '';
		if (!defined $cpu->{'bugs-hash'}){
			if ($cpu->{'bugs-string'}){
				my @proc_bugs = split(/\s+/, $cpu->{'bugs-string'});
				@proc_bugs = sort @proc_bugs;
				$value = join(' ', @proc_bugs);
			}
			else {
				$value = main::message('cpu-bugs-null');
			}
		}
		if ($use{'filter-vulnerabilities'} && 
			(defined $cpu->{'bugs-hash'} || $cpu->{'bugs-string'})){
			$value = $filter_string;
			undef $cpu->{'bugs-hash'};
		}
		push(@$rows, {
		main::key($num++,1,1,'Vulnerabilities') => $value,
		},);
		if (defined $cpu->{'bugs-hash'}){
			$j = scalar @$rows;
			foreach my $key (sort keys %{$cpu->{'bugs-hash'}}){
				$rows->[$j]{main::key($num++,1,2,'Type')} = $key;
				$rows->[$j]{main::key($num++,0,3,$cpu->{'bugs-hash'}->{$key}[0])} = $cpu->{'bugs-hash'}->{$key}[1];
				$j++;
			}
		}
	}
	eval $end if $b_log;
}

# $num, $rows passed by reference
sub full_output_caches {
	eval $start if $b_log;
	my ($j,$properties,$num,$rows) = @_;
	my $value = '';
	if (!$properties->{'l1-cache'} && !$properties->{'l2-cache'} && 
		!$properties->{'l3-cache'}){
		$value = ($properties->{'cache'}) ? $properties->{'cache'} : 'N/A';
	}
	$rows->[$j]{main::key($$num++,1,2,'cache')} = $value;
	if ($extra > 0 && $properties->{'l1-cache'}){
		$rows->[$j]{main::key($$num++,2,3,'L1')} = $properties->{'l1-cache'};
		if ($b_admin && ($properties->{'l1d-desc'} || $properties->{'l1i-desc'})){
			my $desc = '';
			if ($properties->{'l1d-desc'}){
				$desc .= 'd-' . $properties->{'l1d-desc'};
			}
			if ($properties->{'l1i-desc'}){
				$desc .= '; ' if $desc;
				$desc .= 'i-' . $properties->{'l1i-desc'};
			}
			$rows->[$j]{main::key($$num++,0,4,'desc')} = $desc;
		}
	}
	# $rows->[$j]{main::key($$num++,1,$l,$key)} = $support;
	if (!$value){
		$properties->{'l2-cache'} = ($properties->{'l2-cache'}) ? $properties->{'l2-cache'} : 'N/A';
		$rows->[$j]{main::key($$num++,1,3,'L2')} = $properties->{'l2-cache'};
		if ($b_admin && $properties->{'l2-desc'}){
			$rows->[$j]{main::key($$num++,0,4,'desc')} = $properties->{'l2-desc'};
		}
	}
	if ($extra > 0 && $properties->{'l3-cache'}){
		$rows->[$j]{main::key($$num++,1,3,'L3')} = $properties->{'l3-cache'};
		if ($b_admin && $properties->{'l3-desc'}){
			$rows->[$j]{main::key($$num++,0,4,'desc')} = $properties->{'l3-desc'};
		}
	}
	if ($properties->{'cache-check'}){
		$rows->[$j]{main::key($$num++,0,3,'note')} = $properties->{'cache-check'};
	}
	eval $end if $b_log;
}

sub short_output {
	eval $start if $b_log;
	my ($rows,$cpu) = @_;
	my $num = 0;
	$cpu->[1] ||= main::message('cpu-model-null');
	$cpu->[2] ||= 'N/A';
	push(@$rows,{
	main::key($num++,1,1,'Info') => $cpu->[0] . ' ' . $cpu->[1] . ' [' . $cpu->[2] . ']'
	#main::key($num++,0,2,'type') => $cpu->[2],
	});
	if ($extra > 0){
		$rows->[0]{main::key($num++,1,2,'arch')} = $cpu->[8];
		if ($cpu->[9]){
			$rows->[0]{main::key($num++,0,3,'note')} = $cpu->[9];
		}
	}
	my $value = ($cpu->[7]) ? '' : $cpu->[4];
	$rows->[0]{main::key($num++,1,2,$cpu->[3])} = $value;
	if ($cpu->[7]){
		$rows->[0]{main::key($num++,0,3,$cpu->[7])} = $cpu->[4];
	}
	if ($cpu->[6]){
		$rows->[0]{main::key($num++,0,3,$cpu->[5])} = $cpu->[6];
	}
	eval $end if $b_log;
}

## SHORT OUTPUT DATA ##
sub short_data {
	eval $start if $b_log;
	my $num = 0;
	my ($cpu,$data,%speeds);
	my $sys = '/sys/devices/system/cpu/cpufreq/policy0';
	# NOTE: : Permission denied, ie, this is not always readable
	# /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq
	if (my $file = $system_files{'proc-cpuinfo'}){
		$cpu = cpuinfo_data($file);
	}
	elsif ($bsd_type){
		my ($key1,$val1) = ('','');
		if ($alerts{'sysctl'}){
			if ($alerts{'sysctl'}->{'action'} eq 'use'){
# 				$key1 = 'Status';
# 				$val1 = main::message('dev');
				$cpu = sysctl_data($type);
			}
			else {
				$key1 = ucfirst($alerts{'sysctl'}->{'action'});
				$val1 = $alerts{'sysctl'}->{'message'};
				$data = ({main::key($num++,0,1,$key1) => $val1,});
				return $data;
			}
		}
	}
	# $cpu{'cur-freq'} = $cpu[0]->{'core-id'}[0]{'speed'};
	$data = prep_short_data($cpu);
	eval $end if $b_log;
	return $data;
}

sub prep_short_data {
	eval $start if $b_log;
	my ($cpu_data) = @_;
	my $properties = cpu_properties($cpu_data);
	my ($cpu,$speed_key,$speed,$type) = ('','speed',0,'');
	$cpu = $cpu_data->{'model_name'} if $cpu_data->{'model_name'};
 	$type = $properties->{'cpu-type'} if $properties->{'cpu-type'};
 	$speed_key = $properties->{'speed-key'} if $properties->{'speed-key'};
 	$speed = $properties->{'speed'} if $properties->{'speed'};
 	my $result = [
 	$properties->{'topology-string'},
 	$cpu,
 	$type,
 	$speed_key,
 	$speed,
 	$properties->{'min-max-key'},
 	$properties->{'min-max'},
 	$properties->{'avg-speed-key'},
 	];
 	if ($extra > 0){
		$cpu_data->{'arch'} ||= 'N/A';
		$result->[8] = $cpu_data->{'arch'};
		$result->[9] = $cpu_data->{'arch-note'};
 	}
	eval $end if $b_log;
	return $result;
}

## PRIMARY DATA GENERATORS ##
sub cpuinfo_data {
	eval $start if $b_log;
	my ($file)=  @_;
	my ($cpu,$arch,$note,$temp);
	# has to be set above fake cpu section
	set_cpu_data(\$cpu);
	set_fake_data() if $fake{'cpu'} && !$loaded{'cpu-fake-data'};
	# sleep is also set in front of sysctl_data for BSDs, same idea
	my $sleep = $cpu_sleep * 1000000;
	if ($b_hires){
		eval 'Time::HiRes::usleep($sleep)';
	}
	else {
		select(undef, undef, undef, $cpu_sleep);
	}
	# Run first to get raw as possible speeds
	cpuinfo_speed_sys(\$cpu) if $fake{'cpu'} || -e '/sys/devices/system/cpu/';
	cpuinfo_data_grabber($file,\$cpu->{'type'}) if !$loaded{'cpuinfo'};
	$cpu->{'type'} = cpu_vendor($cpu_arch) if $cpu_arch eq 'elbrus'; # already set to lower
	my ($core_count,$proc_count,$speed) = (0,0,0);
	my ($b_block_1) = (1);
	# need to prime for arm cpus, which do not have physical/core ids usually
	# level 0 is phys id, level 1 is die id, level 2 is core id
	# note, there con be a lot of processors, 32 core HT would have 64, for example.
	foreach my $block (@cpuinfo){
		# get the repeated data for CPUs, after assign the dynamic per core data
		next if !$block;
		if ($b_block_1){
			$b_block_1 = 0;
			# this may also kick in for centaur/via types, but no data available, guess
			if (!$cpu->{'type'} && $block->{'vendor_id'}){
				$cpu->{'type'} = cpu_vendor($block->{'vendor_id'});
			}
			# PPC can use 'cpu', MIPS 'cpu model'
			$temp = main::get_defined($block->{'model name'},$block->{'cpu'},
			 $block->{'cpu model'});
			if ($temp){
				$cpu->{'model_name'} = $temp;
				$cpu->{'model_name'} = main::clean($cpu->{'model_name'});
				$cpu->{'model_name'} = clean_cpu($cpu->{'model_name'});
				if ($risc{'arm'} || $cpu->{'model_name'} =~ /ARM|AArch/i){
					$cpu->{'type'} = 'arm';
					if ($cpu->{'model_name'} =~ /(.*)\srev\s([\S]+)\s(\(([\S]+)\))?/){
						$cpu->{'model_name'} = $1;
						$cpu->{'stepping'} = $2;
						if ($4){
							$cpu->{'arch'} = $4;
							if ($cpu->{'model_name'} !~ /\Q$cpu->{'arch'}\E/i){
								$cpu->{'model_name'} .= ' ' . $cpu->{'arch'};
							}
						}
						# print "p0:\n";
					}
				}
				elsif ($risc{'mips'} || $cpu->{'model_name'} =~ /mips/i){
					$cpu->{'type'} = 'mips';
				}
			}
			$temp = main::get_defined($block->{'architecture'},
			 $block->{'cpu family'},$block->{'cpu architecture'});
			if ($temp){
				if ($temp =~ /^\d+$/){
					# translate integers to hex
					$cpu->{'family'} = uc(sprintf("%x",$temp));
				}
				elsif ($risc{'arm'}){
					$cpu->{'arch'} = $temp;
				}
			}
			# note: stepping and ARM cpu revision are integers
			$temp = main::get_defined($block->{'stepping'},$block->{'cpu revision'});
			# can be 0, but can be 'unknown'
			if (defined $temp || 
			 ($cpu->{'type'} eq 'elbrus' && defined $block->{'revision'})){
				$temp = $block->{'revision'} if defined $block->{'revision'};
				if ($temp =~ /^\d+$/){
					$cpu->{'stepping'} = uc(sprintf("%x",$temp));
				}
			}
			# PPC revision is a string, but elbrus revision is hex
			elsif (defined $block->{'revision'}){
				$cpu->{'revision'} = $block->{'revision'};
			}
			# this is hex so uc for cpu arch id. raspi 4 has Model rather than Hardware
			if (defined $block->{'model'}){
				# can be 0, but can be 'unknown'
				$cpu->{'model-id'} = uc(sprintf("%x",$block->{'model'}));
			}
			if ($block->{'cpu variant'}){
				$cpu->{'model-id'} = uc($block->{'cpu variant'});
				$cpu->{'model-id'} =~ s/^0X//;
			}
			 # this is per cpu, not total if > 1 pys cpus
			if (!$cpu->{'cores'} && $block->{'cpu cores'}){
				$cpu->{'cores'} = $block->{'cpu cores'};
			}
			## this is only for -C full cpu output
			if ($type eq 'full'){
				# note: in cases where only cache is there, don't guess, it can be L1,
				# L2, or L3, but never all of them added togehter, so give up.
				if ($block->{'cache size'} && 
					$block->{'cache size'} =~ /(\d+\s*[KMG])i?B?$/){
					$cpu->{'cache'} = main::translate_size($1);
				}
				if ($block->{'l1 cache size'} && 
				 $block->{'l1 cache size'} =~ /(\d+\s*[KMG])i?B?$/){
					$cpu->{'l1-cache'} = main::translate_size($1);
				}
				if ($block->{'l2 cache size'} && 
					$block->{'l2 cache size'} =~ /(\d+\s*[KMG])i?B?$/){
					$cpu->{'l2-cache'} = main::translate_size($1);
				}
				if ($block->{'l3 cache size'} && 
				 $block->{'l3 cache size'} =~ /(\d+\s*[KMG])i?B?$/){
					$cpu->{'l3-cache'} = main::translate_size($1);
				}
				$temp = main::get_defined($block->{'flags'} || $block->{'features'});
				if ($temp){
					$cpu->{'flags'} = $temp;
				}
				if ($b_admin){
					# note: not used unless maybe /sys data missing?
					if ($block->{'bugs'}){
						$cpu->{'bugs-string'} = $block->{'bugs'};
					}
					# unlike family and model id, microcode appears to be hex already
					if ($block->{'microcode'}){
						if ($block->{'microcode'} =~ /0x/){
							$cpu->{'microcode'} = uc($block->{'microcode'});
							$cpu->{'microcode'} =~ s/^0X//;
						}
						else {
							$cpu->{'microcode'} = uc(sprintf("%x",$block->{'microcode'}));
						}
					}
				}
			}
		}
		# These occurs in a separate block with E2C3, last in cpuinfo blocks,
		# otherwise per block in E8C variants
		if ($cpu->{'type'} eq 'elbrus' && (!$cpu->{'l1i-cache'} && 
		 !$cpu->{'l1d-cache'} && !$cpu->{'l2-cache'} && !$cpu->{'l3-cache'})){
			# note: cache0 is L1i and cache1 L1d. cp_caches_fallback handles
			if ($block->{'cache0'} && 
				$block->{'cache0'} =~ /size\s*=\s*(\d+)K\s/){
				$cpu->{'l1i-cache'} = $1;
			}
			if ($block->{'cache1'} && 
				$block->{'cache1'} =~ /size\s*=\s*(\d+)K\s/){
				$cpu->{'l1d-cache'} = $1;
			}
			if ($block->{'cache2'} && 
				$block->{'cache2'} =~ /size\s*=\s*(\d+)(K|M)\s/){
				$cpu->{'l2-cache'} = ($2 eq 'M') ? ($1*1024) : $1;
			}
			if ($block->{'cache3'} &&
				$block->{'cache3'} =~ /size\s*=\s*(\d+)(K|M)\s/){
				$cpu->{'l3-cache'} = ($2 eq 'M') ? ($1*1024) : $1;
			}
		}
		## Start incrementers
		$temp = main::get_defined($block->{'cpu mhz'},$block->{'clock'});
		if ($temp){
			$speed = clean_speed($temp);
			push(@{$cpu->{'processors'}},$speed);
		}
		# new arm shows bad bogomip value, so don't use it, however, ancient
		# cpus, intel 486, can have super low bogomips, like 33.17
		if ($extra > 0 && $block->{'bogomips'} && ((%risc && 
			$block->{'bogomips'} > 50) || !%risc)){
			$cpu->{'bogomips'} += $block->{'bogomips'};
		}
		# just to get core counts for ARM/MIPS/PPC systems
		if (defined $block->{'processor'} && !$temp){
			if ($block->{'processor'} =~ /^\d+$/){
				push(@{$cpu->{'processors'}},0);
			}
		}
		# note: for alder lake, could vary, depending on if e or p core but we 
		# only care aobut the highest value for crude logic here
		if ($block->{'siblings'} && 
		 (!$cpu->{'siblings'} || $block->{'siblings'} > $cpu->{'siblings'})){
			$cpu->{'siblings'} = $block->{'siblings'};
		}
		# Ignoring trying to catch dies with $block->{'physical id'}, 
		# that's too buggy for cpuinfo
		if (defined $block->{'core id'}){
			# https://www.pcworld.com/article/3214635/components-processors/ryzen-threadripper-review-we-test-amds-monster-cpu.html
			my $phys = (defined $block->{'physical id'}) ? $block->{'physical id'}: 0;
			my $die_id = 0;
			if (!grep {$_ eq $block->{'core id'}} @{$cpu->{'ids'}->[$phys][$die_id]}){
				push(@{$cpu->{'ids'}->[$phys][$die_id]},$block->{'core id'});
			}
		}
	}
	undef @cpuinfo; # we're done with it, dump it
	undef %cpuinfo_machine;
	if (%risc){
		if (!$cpu->{'type'}){
			$cpu->{'type'} = $risc{'id'};
		}
		if (!$bsd_type){
			my $system_cpus = system_cpu_name();
			$cpu->{'system-cpus'} = $system_cpus if %$system_cpus;
		}
	}
	main::log_data('dump','%$cpu',$cpu) if $b_log;
	print 'cpuinfo: ', Data::Dumper::Dumper $cpu if $dbg[8];
	eval $end if $b_log;
	return $cpu;
}

# args: 0: $cpu ref; 
sub cpuinfo_speed_sys {
	eval $start if $b_log;
	my @data;
	my $val_id = 0;
	# Run this logic first to make sure we get the speeds as raw as possible. 
	# Not in function to avoid unnecessary cpu use, we have slept right before.
	# ARM and legacy systems etc do not always have cpufreq.
	# note that there can be a definite cost to reading scaling_cur_freq, which 
	# must be generated on the fly based on some time snippet sample.
	if ($fake{'cpu'}){
		if ($fake_data{'sys'} && (my @fake = main::reader($fake_data{'sys'},'strip'))){
			my $pattern = '/sys/devices/system/cpu/cpufreq/policy\d+/(affected_cpus|';
			# reading cpuinfo WAY faster than scaling, but root only
			if (grep {m%/sys/devices/system/cpu/cpufreq/policy0/cpuinfo_cur_freq%} @fake){
				$pattern .= 'cpuinfo_cur_freq)';
			}
			else {
				$pattern .= 'scaling_cur_freq)';
			}
			@data = grep {m%^$pattern%} @fake;
			# print Data::Dumper::Dumper \@fake,"\n";
		}
		$val_id = 1;
	}
	else {
		my $glob = '/sys/devices/system/cpu/cpu*/cpufreq/{affected_cpus,';
		# reading cpuinfo WAY faster than scaling, but root only
		if (-r '/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq'){
			$glob .= 'cpuinfo_cur_freq}';
		}
		else {
			$glob .= 'scaling_cur_freq}';
		}
		@data = main::globber($glob);
	}
	my ($error,$file,$key,%working,%freq,@value);
	foreach (@data){
		next if !$fake{'cpu'} && ! -r $_;
		undef $error;
		# print "loop: $_\n";
		my $fh;
		# $fh always non null, even on error
		if (!$fake{'cpu'}){
			open($fh, '<', $_) or $error = $!;
		}
		if (!$error){
			if (m%/sys/devices/system/cpu/(cpufreq/)?(cpu|policy)(\d+)/(cpufreq/)?(affected_cpus|(cpuinfo|scaling)_cur_freq)%){
				$key = $3;
				$file = $5;
				if (!$fake{'cpu'}){
					chomp(@value = <$fh>);
					close $fh;
				}
				else {
					@value = split(/::/,$_,2);
				}
				if ($file eq 'affected_cpus'){
					# chomp seems to turn undefined into '', not sure why. Behavior varies
					# so check for both cases.
					if (defined $value[$val_id] && $value[$val_id] ne ''){
						$working{$key}->[0] = $value[$val_id];
					}
				}
				else {
					$working{$key}->[1] = clean_speed($value[$val_id],'khz');
				}
			}
		}
	}
	if (%working){
		foreach (keys %working){
			$freq{sprintf("%04d",$_)} = $working{$_}->[1] if defined $working{$_}->[0];
		}
		${$_[0]}->{'sys-freq'} = \%freq if %freq;
		# print 'result: ', Data::Dumper::Dumper $_[0];
	}
	eval $end if $b_log;
}

sub cpuinfo_data_grabber {
	eval $start if $b_log;
	my ($file,$cpu_type) = @_; # type by ref
	$loaded{'cpuinfo'} = 1;
	# use --arm flag when testing arm cpus, and --fake-cpu to trigger fake data
	$file = $fake_data{'cpuinfo'} if $fake{'cpu'};
	my $raw = main::reader($file,'','ref');
	@$raw = map {$_ =~ s/^\s*$/~~~/;$_;} @$raw;
	push(@$raw,'~~~') if @$raw;
	my ($b_processor,$key,$value);
	my ($i) = (0);
	my @key_tests = ('firmware','hardware','mmu','model','motherboard',
	 'platform','system type','timebase');
	foreach my $row (@$raw){
		($key,$value) = split(/\s*:\s*/,$row,2);
		next if !defined $key;
		# ARM: 'Hardware' can appear in processor block; system type (mips)
		# ARM: CPU revision; machine: Revision/PPC: revision (CPU implied)
		# orangepi3 has Hardware/Processor embedded in processor block
		if (%risc && ((grep {lc($key) eq $_} @key_tests) || 
		 (!$risc{'ppc'} && lc($key) eq 'revision'))){
			$b_processor = 0;
		}
		else {
			$b_processor = 1;
		}
		if ($b_processor){
			if ($key eq '~~~'){
				$i++;
				next;
			}
			# A small handful of ARM devices use Processor instead of 'model name'
			# Processor   : AArch64 Processor rev 4 (aarch64)
			# Processor : Feroceon 88FR131 rev 1 (v5l)
			$key = ($key eq 'Processor') ? 'model name' : lc($key);
			$cpuinfo[$i]->{$key} = $value;
		}
		else {
			next if $cpuinfo_machine{lc($key)}; 
			$cpuinfo_machine{lc($key)} = $value;
		}
	}
	if ($b_log){
		main::log_data('dump','@cpuinfo',\@cpuinfo);
		main::log_data('dump','%cpuinfo_machine',\%cpuinfo_machine);
	}
	if ($dbg[41]){
		print Data::Dumper::Dumper \@cpuinfo;
		print Data::Dumper::Dumper \%cpuinfo_machine;
	}
	eval $end if $b_log;
}

sub cpu_sys_data {
	eval $start if $b_log;
	my $sys_freq = $_[0];
	my $cpu_sys = {};
	my $working = sys_data_grabber();
	return $cpu_sys if !%$working;
	$cpu_sys->{'data'} = $working->{'data'} if $working->{'data'};
	my ($core_id,$fake_core_id,$phys_id,) = (0,0,-1);
	my (%cache_ids,@ci_freq_max,@ci_freq_min,@sc_freq_max,@sc_freq_min);
	foreach my $key (sort keys %{$working->{'cpus'}}){
		($core_id,$phys_id) = (0,0);
		my $cpu_id = $key + 0;
		my $speed;
		my $cpu = $working->{'cpus'}{$key};
		if (defined $cpu->{'topology'}{'physical_package_id'}){
			$phys_id = sprintf("%04d",$cpu->{'topology'}{'physical_package_id'});
		}
		if (defined $cpu->{'topology'}{'core_id'}){
			# id is not consistent, seen 5 digit id
			$core_id = sprintf("%08d",$cpu->{'topology'}{'core_id'});
			if ($fake{'cpu'}){
				if (defined $cpu->{'cpufreq'}{'scaling_cur_freq'} && 
				$cpu->{'cpufreq'}{'affected_cpus'} && 
				$cpu->{'cpufreq'}{'affected_cpus'} ne 'UNDEFINED' &&
				# manually generated cpu debuggers will show '', not UNDEFINED
				$cpu->{'cpufreq'}{'affected_cpus'} ne ''){
					$speed = clean_speed($cpu->{'cpufreq'}{'scaling_cur_freq'},'khz');
				}
			}
			elsif (defined $sys_freq && defined $sys_freq->{$key}){
				$speed = $sys_freq->{$key};
			}
			if (defined $speed){
				push(@{$cpu_sys->{'cpus'}{$phys_id}{'cores'}{$core_id}},$speed);
				push(@{$cpu_sys->{'data'}{'speeds'}{'all'}},$speed);
			}
			else {
				push(@{$cpu_sys->{'data'}{'speeds'}{'all'}},0);
				# seen cases, riscv, where core id, phys id, are all -1
				my $id = ($core_id != -1) ? $core_id: $fake_core_id++;
				push(@{$cpu_sys->{'cpus'}{$phys_id}{'cores'}{$id}},0);
			}
			# Only use if topology core-id exists, some virtualized cpus can list 
			# frequency data for the non available cores, but those do not show 
			# topology data.
			# For max / min, we want to prep for the day 1 pys cpu has > 1 min/max freq
			if (defined $cpu->{'cpufreq'}{'cpuinfo_max_freq'}){
				$cpu->{'cpufreq'}{'cpuinfo_max_freq'} = clean_speed($cpu->{'cpufreq'}{'cpuinfo_max_freq'},'khz');
				if (!grep {$_ eq $cpu->{'cpufreq'}{'cpuinfo_max_freq'}} @ci_freq_max){
					push(@ci_freq_max,$cpu->{'cpufreq'}{'cpuinfo_max_freq'});
				}
				if (!grep {$_ eq $cpu->{'cpufreq'}{'cpuinfo_max_freq'}} @{$cpu_sys->{'cpus'}{$phys_id}{'max-freq'}}){
					push(@{$cpu_sys->{'cpus'}{$phys_id}{'max-freq'}},$cpu->{'cpufreq'}{'cpuinfo_max_freq'});
				}
			}
			if (defined $cpu->{'cpufreq'}{'cpuinfo_min_freq'}){
				$cpu->{'cpufreq'}{'cpuinfo_min_freq'} = clean_speed($cpu->{'cpufreq'}{'cpuinfo_min_freq'},'khz');
				if (!grep {$_ eq $cpu->{'cpufreq'}{'cpuinfo_min_freq'}} @ci_freq_min){
					push(@ci_freq_min,$cpu->{'cpufreq'}{'cpuinfo_min_freq'});
				}
				if (!grep {$_ eq $cpu->{'cpufreq'}{'cpuinfo_min_freq'}} @{$cpu_sys->{'cpus'}{$phys_id}{'min-freq'}}){
					push(@{$cpu_sys->{'cpus'}{$phys_id}{'min-freq'}},$cpu->{'cpufreq'}{'cpuinfo_min_freq'});
				}
			}
			if (defined $cpu->{'cpufreq'}{'scaling_max_freq'}){
				$cpu->{'cpufreq'}{'scaling_max_freq'} = clean_speed($cpu->{'cpufreq'}{'scaling_max_freq'},'khz');
				if (!grep {$_ eq $cpu->{'cpufreq'}{'scaling_max_freq'}} @sc_freq_max){
					push(@sc_freq_max,$cpu->{'cpufreq'}{'scaling_max_freq'});
				}
				if (!grep {$_ eq $cpu->{'cpufreq'}{'scaling_max_freq'}} @{$cpu_sys->{'cpus'}{$phys_id}{'max-freq'}}){
					push(@{$cpu_sys->{'cpus'}{$phys_id}{'max-freq'}},$cpu->{'cpufreq'}{'scaling_max_freq'});
				}
			}
			if (defined $cpu->{'cpufreq'}{'scaling_min_freq'}){
				$cpu->{'cpufreq'}{'scaling_min_freq'} = clean_speed($cpu->{'cpufreq'}{'scaling_min_freq'},'khz');
				if (!grep {$_ eq $cpu->{'cpufreq'}{'scaling_min_freq'}} @sc_freq_min){
					push(@sc_freq_min,$cpu->{'cpufreq'}{'scaling_min_freq'});
				}
				if (!grep {$_ eq $cpu->{'cpufreq'}{'scaling_min_freq'}} @{$cpu_sys->{'cpus'}{$phys_id}{'min-freq'}}){
					push(@{$cpu_sys->{'cpus'}{$phys_id}{'min-freq'}},$cpu->{'cpufreq'}{'scaling_min_freq'});
				}
			}
			if (defined $cpu->{'cpufreq'}{'scaling_governor'}){
				if (!grep {$_ eq $cpu->{'cpufreq'}{'scaling_governor'}} @{$cpu_sys->{'cpus'}{$phys_id}{'governor'}}){
					push(@{$cpu_sys->{'cpus'}{$phys_id}{'governor'}},$cpu->{'cpufreq'}{'scaling_governor'});
				}
			}
			if (defined $cpu->{'cpufreq'}{'scaling_driver'}){
				$cpu_sys->{'cpus'}{$phys_id}{'scaling-driver'} = $cpu->{'cpufreq'}{'scaling_driver'};
			}
		}
		if (!defined $cpu_sys->{'data'}{'cpufreq-boost'} && defined $cpu->{'cpufreq'}{'cpb'}){
			$cpu_sys->{'data'}{'cpufreq-boost'} = $cpu->{'cpufreq'}{'cpb'};
		}
		if (defined $cpu->{'topology'}{'core_cpus_list'}){
			$cpu->{'topology'}{'thread_siblings_list'} = $cpu->{'topology'}{'core_cpus_list'};
		}
		if (defined $cpu->{'cache'} && keys %{$cpu->{'cache'}} > 0){
			foreach my $key2 (sort keys %{$cpu->{'cache'}}){
				my $cache = $cpu->{'cache'}{$key2};
				my $type = ($cache->{'type'} =~ /^([DI])/i) ? lc($1): '';
				my $level = 'l' . $cache->{'level'} . $type;
				# Very old systems, 2.6.xx do not have shared_cpu_list
				if (!defined $cache->{'shared_cpu_list'} && defined $cache->{'shared_cpu_map'}){
					$cache->{'shared_cpu_list'} = $cache->{'shared_cpu_map'};
				}
				# print Data::Dumper::Dumper $cache;
				if (defined $cache->{'shared_cpu_list'}){
					# not needed, the cpu is always in the range
					# my $range = main::regex_range($cache->{'shared_cpu_list'});
					my $size = main::translate_size($cache->{'size'});
					# print "cpuid: $cpu_id phys-core: $phys_id-$core_id level: $level range: $range  shared: $cache->{'shared_cpu_list'}\n";
					if (!(grep {$_ eq $cache->{'shared_cpu_list'}} @{$cache_ids{$phys_id}->{$level}})){
						push(@{$cache_ids{$phys_id}->{$level}},$cache->{'shared_cpu_list'});
						push(@{$cpu_sys->{'cpus'}{$phys_id}{'caches'}{$level}},$size);
					}
				}
			}
		}
		# die_id is relatively new, core_siblings_list has been around longer
		if (defined $cpu->{'topology'}{'die_id'} || 
		defined $cpu->{'topology'}{'core_siblings_list'}){
			my $die = $cpu->{'topology'}{'die_id'};
			$die = $cpu->{'topology'}{'core_siblings_list'} if !defined $die;
			if (!grep {$_ eq $die} @{$cpu_sys->{'cpus'}{$phys_id}{'dies'}}){
				push(@{$cpu_sys->{'cpus'}{$phys_id}{'dies'}},$die);
			}
		}
	}
	if (defined $cpu_sys->{'data'}{'cpufreq-boost'} &&
	$cpu_sys->{'data'}{'cpufreq-boost'} =~ /^[01]$/){
		if ($cpu_sys->{'data'}{'cpufreq-boost'}){
			$cpu_sys->{'data'}{'cpufreq-boost'} = 'enabled';
		}
		else {
			$cpu_sys->{'data'}{'cpufreq-boost'} = 'disabled';
		}
	}
	# cpuinfo_max_freq:["2000000"] cpuinfo_max_freq:["1500000"] 
	# cpuinfo_min_freq:["200000"]
	if (@ci_freq_max){
		$cpu_sys->{'data'}{'speeds'}{'max-freq'} = join(':',@ci_freq_max);
	}
	if (@ci_freq_min){
		$cpu_sys->{'data'}{'speeds'}{'min-freq'} = join(':',@ci_freq_min);
	}
	# also handle off chance that cpuinfo_min/max not set, but scaling_min/max there
	if (@sc_freq_max){
		$cpu_sys->{'data'}{'speeds'}{'scaling-max-freq'} = join(':',@sc_freq_max);
		if (!$cpu_sys->{'data'}{'speeds'}{'max-freq'}){
			$cpu_sys->{'data'}{'speeds'}{'max-freq'} = $cpu_sys->{'data'}{'speeds'}{'scaling-max-freq'};
		}
	}
	if (@sc_freq_min){
		$cpu_sys->{'data'}{'speeds'}{'scaling-min-freq'} = join(':',@sc_freq_min);
		if (!$cpu_sys->{'data'}{'speeds'}{'min-freq'}){
			$cpu_sys->{'data'}{'speeds'}{'min-freq'} = $cpu_sys->{'data'}{'speeds'}{'scaling-min-freq'};
		}
	}
	# this corrects a bug we see sometimes in min/max frequencies
	if ((scalar @ci_freq_max < 2 && scalar @ci_freq_min < 2) && 
	(defined $cpu_sys->{'data'}{'speeds'}{'min-freq'} && 
	defined $cpu_sys->{'data'}{'speeds'}{'max-freq'}) &&
	($cpu_sys->{'data'}{'speeds'}{'min-freq'} > $cpu_sys->{'data'}{'speeds'}{'max-freq'} || 
	$cpu_sys->{'data'}{'speeds'}{'min-freq'} == $cpu_sys->{'data'}{'speeds'}{'max-freq'})){
		$cpu_sys->{'data'}{'speeds'}{'min-freq'} = 0;
	}
	main::log_data('dump','%$cpu_sys',$cpu_sys) if $b_log;
	print 'cpu-sys: ', Data::Dumper::Dumper $cpu_sys if $dbg[8];
	eval $end if $b_log;
	return $cpu_sys;
}

sub sys_data_grabber {
	eval $start if $b_log;
	my (@files);
	set_fake_data() if $fake{'cpu'} && !$loaded{'cpu-fake-data'};
	# this data has to match the data in cpuinfo grabber fake cpu, and remember
	# to use --arm flag if arm tests
	if ($fake{'cpu'}){
		# print "$fake_data{'sys'}\n";
		@files = main::reader($fake_data{'sys'}) if $fake_data{'sys'};
		# print Data::Dumper::Dumper \@files;
	}
	# There's a massive time hit reading full globbed set of files, so grab and 
	# read only what we need.
	else {
		my $glob = '/sys/devices/system/cpu/{';
		if ($dbg[43]){
			$glob .= 'cpufreq,cpu*/topology,cpu*/cpufreq,cpu*/cache/index*,smt,vulnerabilities}/*';
		}
		else {
			$glob .= 'cpu*/topology/{core_cpus_list,core_id,core_siblings_list,die_id,';
			$glob .= 'physical_package_id,thread_siblings_list}';
			$glob .= ',cpufreq/{boost,ondemand}';
			$glob .= ',cpu*/cpufreq/{cpb,cpuinfo_max_freq,cpuinfo_min_freq,';
			$glob .= 'scaling_max_freq,scaling_min_freq';
			$glob .= ',scaling_driver,scaling_governor' if $type eq 'full' && $b_admin;
			$glob .= '}';
			if ($type eq 'full'){
				$glob .= ',cpu*/cache/index*/{level,shared_cpu_list,shared_cpu_map,size,type}';
			}
			$glob .= ',smt/{active,control}';
			$glob .= ',vulnerabilities/*' if $b_admin;
			$glob .= '}';
		}
		# print "sys glob: $glob\n";
		@files = main::globber($glob);
	}
	main::log_data('dump','@files',\@files) if $b_log;
	print Data::Dumper::Dumper \@files if $dbg[40];
	my ($b_bug,$b_cache,$b_freq,$b_topo,$b_main);
	my $working = {};
	my ($main_id,$main_key,$holder,$id,$item,$key) = ('','','','','','');
	# need to return hash reference on failure or old systems complain
	return $working if !@files; 
	foreach (sort @files){
		if ($fake{'cpu'}){
			($_,$item) = split(/::/,$_,2);
		}
		else {
			next if -d $_ || ! -e $_;
			undef $item;
		}
		$key = $_;
		$key =~ m|/([^/]+)/([^/]+)$|;
		my ($key_1,$key_2) = ($1,$2);
		if (m|/cpu(\d+)/|){
			if (!$holder || $1 ne $holder){
				$id = sprintf("%04d",$1);
				$holder = $1;
			}
			$b_bug = 0;
			$b_cache = 0;
			$b_freq = 0;
			$b_main = 0;
			$b_topo = 0;
			if ($key_1 eq 'cpufreq'){
				$b_freq = 1;
				$main_key = $key_2;
				$key = $key_1;
			}
			elsif ($key_1 eq 'topology'){
				$b_topo = 1;
				$main_key = $key_2;
				$key = $key_1;
			}
			elsif ($key_1 =~ /^index(\d+)$/){
				$b_cache = 1;
				$main_key = $key_2;
				$main_id =  sprintf("%02d",$1);
				$key = 'cache';
			}
		}
		elsif ($key_1 eq 'vulnerabilities'){
			$id = $key_1;
			$key = $key_2;
			$b_bug = 1;
			$b_cache = 0;
			$b_main = 0;
			$b_freq = 0;
			$b_topo = 0;
			$main_key = '';
			$main_id = '';
		}
		else {
			$id = $key_1 . '-' . $key_2;
			$b_bug = 0;
			$b_cache = 0;
			$b_main = 1;
			$b_freq = 0;
			$b_topo = 0;
			$main_key = '';
			$main_id = '';
		}
		if (!$fake{'cpu'}){
			if (-r $_) {
				my $error;
				# significantly faster to skip reader() and do it directly
				# $fh always non null, even on error
				open(my $fh, '<', $_) or $error = $!;
				if (!$error){
					chomp(my @value = <$fh>);
					close $fh;
					$item = $value[0];
				}
				 # $item = main::reader($_,'strip',0);
			}
			else {
				$item = main::message('root-required');
			}
			$item = main::message('undefined') if !defined $item;
		}
		# print "$key_1 :: $key_2 :: $item\n";
		if ($b_main){
			$working->{'data'}{$id} = $item;
		}
		elsif ($b_bug){
			my $type = ($item =~ /^Mitigation:/) ? 'mitigation': 'status';
			$item =~ s/Mitigation: //;
			$working->{'data'}{$id}{$key} = [$type,$item];
		}
		elsif ($b_cache){
			$working->{'cpus'}{$id}{$key}{$main_id}{$main_key} = $item;
		}
		elsif ($b_freq || $b_topo){
			$working->{'cpus'}{$id}{$key}{$main_key} = $item;
		}
	}
	main::log_data('dump','%$working',$working) if $b_log;
	print Data::Dumper::Dumper $working if $dbg[39];
	eval $end if $b_log;
	return $working;
}

# Set in one place to make sure we get them all consistent
sub set_fake_data {
	$loaded{'cpu-fake-data'} = 1;
	my ($ci,$sys);
	## CPUINFO DATA FILES ##
	## ARM/MIPS
	# $ci = "$fake_data_dir/cpu/arm/arm-4-core-pinebook-1.txt";
	# $ci = "$fake_data_dir/cpu/arm/armv6-single-core-1.txt";
	# $ci = "$fake_data_dir/cpu/arm/armv7-dual-core-1.txt";
	# $ci = "$fake_data_dir/cpu/arm/armv7-new-format-model-name-single-core.txt";
	# $ci = "$fake_data_dir/cpu/arm/arm-2-die-96-core-rk01.txt";
	# $ci = "$fake_data_dir/cpu/arm/arm-shevaplug-1.2ghz.txt";
	# $ci = "$fake_data_dir/cpu/mips/mips-mainusg-cpuinfo.txt";
	# $ci = "$fake_data_dir/cpu/ppc/ppc-debian-ppc64-cpuinfo.txt";
	## x86
	# $ci = "$fake_data_dir/cpu/amd/16-core-32-mt-ryzen.txt";
	# $ci = "$fake_data_dir/cpu/amd/2-16-core-epyc-abucodonosor.txt";
	# $ci = "$fake_data_dir/cpu/amd/2-core-probook-antix.txt";
	# $ci = "$fake_data_dir/cpu/amd/4-core-jean-antix.txt";
	# $ci = "$fake_data_dir/cpu/amd/4-core-althlon-mjro.txt";
	# $ci = "$fake_data_dir/cpu/amd/4-core-apu-vc-box.txt";
	# $ci = "$fake_data_dir/cpu/amd/4-core-a10-5800k-1.txt";
	# $ci = "$fake_data_dir/cpu/intel/1-core-486-fourtysixandtwo.txt";
	# $ci = "$fake_data_dir/cpu/intel/2-core-ht-atom-bruh.txt";
	# $ci = "$fake_data_dir/cpu/intel/core-2-i3.txt";
	# $ci = "$fake_data_dir/cpu/intel/8-core-i7-damentz64.txt";
	# $ci = "$fake_data_dir/cpu/intel/2-10-core-xeon-ht.txt";
	# $ci = "$fake_data_dir/cpu/intel/4-core-xeon-fake-dual-die-zyanya.txt";
	# $ci = "$fake_data_dir/cpu/intel/2-core-i5-fake-dual-die-hek.txt";
	# $ci = "$fake_data_dir/cpu/intel/2-1-core-xeon-vm-vs2017.txt";
	# $ci = "$fake_data_dir/cpu/intel/4-1-core-xeon-vps-frodo1.txt";
	# $ci = "$fake_data_dir/cpu/intel/4-6-core-xeon-no-mt-lathander.txt";
	## Elbrus
	# $cpu_type = 'elbrus'; # uncomment to test elbrus
	# $ci = "$fake_data_dir/cpu/elbrus/elbrus-2c3/cpuinfo.txt";
	# $ci = "$fake_data_dir/cpu/elbrus/1xE1C-8.txt";
	# $ci = "$fake_data_dir/cpu/elbrus/1xE2CDSP-4.txt";
	# $ci = "$fake_data_dir/cpu/elbrus/1xE2S4-3-monocub.txt";
	# $ci = "$fake_data_dir/cpu/elbrus/1xMBE8C-7.txt";
	# $ci = "$fake_data_dir/cpu/elbrus/4xEL2S4-3.txt";
	# $ci = "$fake_data_dir/cpu/elbrus/4xE8C-7.txt";
	# $ci = "$fake_data_dir/cpu/elbrus/4xE2CDSP-4.txt";
	# $ci = "$fake_data_dir/cpu/elbrus/cpuinfo.e8c2.txt";
	
	## CPU CPUINFO/SYS PAIRS DATA FILES ##
	# $ci = "$fake_data_dir/cpu/sys-ci-pairs/android-pocom3-fake-cpuinfo.txt";
	# $sys = "$fake_data_dir/cpu/sys-ci-pairs/android-pocom3-fake-sys.txt";
	# $ci = "$fake_data_dir/cpu/sys-ci-pairs/arm-pine64-cpuinfo-1.txt";v
	# $sys = "$fake_data_dir/cpu/sys-ci-pairs/arm-pine64-sys-1.txt";
	# $ci = "$fake_data_dir/cpu/sys-ci-pairs/arm-riscyslack2-cpuinfo-1.txt";
	# $sys = "$fake_data_dir/cpu/sys-ci-pairs/arm-riscyslack2-sys-1.txt";
	# $ci = "$fake_data_dir/cpu/sys-ci-pairs/ppc-stuntkidz~cpuinfo.txt";
	# $sys = "$fake_data_dir/cpu/sys-ci-pairs/ppc-stuntkidz~sys.txt";
	# $ci = "$fake_data_dir/cpu/sys-ci-pairs/riscv-unmatched-2021~cpuinfo-1.txt";
	# $sys = "$fake_data_dir/cpu/sys-ci-pairs/riscv-unmatched-2021~sys-1.txt";
	# $ci = "$fake_data_dir/cpu/sys-ci-pairs/x86-brickwizard-atom-n270~cpuinfo-1.txt";
	# $sys = "$fake_data_dir/cpu/sys-ci-pairs/x86-brickwizard-atom-n270~sys-1.txt";
	# $ci = "$fake_data_dir/cpu/sys-ci-pairs/x86-amd-phenom-chrisretusn-cpuinfo-1.txt";
	# $sys = "$fake_data_dir/cpu/sys-ci-pairs/x86-amd-phenom-chrisretusn-sys-1.txt";
	# $ci = "$fake_data_dir/cpu/sys-ci-pairs/x86-drgibbon-intel-i7-cpuinfo.txt";
	# $sys = "$fake_data_dir/cpu/sys-ci-pairs/x86-drgibbon-intel-i7-sys.txt";
	# $ci = "$fake_data_dir/cpu/sys-ci-pairs/ryzen-threadripper-1x64-3950x-cpuinfo.txt";
	# $sys = "$fake_data_dir/cpu/sys-ci-pairs/ryzen-threadripper-1x64-3950x-sys.txt";
	# $ci = "$fake_data_dir/cpu/sys-ci-pairs/amd-threadripper-1x12-5945wx-cpuinfo-1.txt";
	# $sys = "$fake_data_dir/cpu/sys-ci-pairs/amd-threadripper-1x12-5945wx-sys-1.txt";
	# $ci = "$fake_data_dir/cpu/sys-ci-pairs/intel-i7-1165G7-4-core-no-smt-cpuinfo.txt";
	# $sys = "$fake_data_dir/cpu/sys-ci-pairs/intel-i7-1165G7-4-core-no-smt-sys.txt";
	 $ci = "$fake_data_dir/cpu/sys-ci-pairs/elbrus-e16c-1-cpuinfo.txt";
	 $sys = "$fake_data_dir/cpu/sys-ci-pairs/elbrus-e16c-1-sys.txt";
	$fake_data{'cpuinfo'} = $ci;
	$fake_data{'sys'} = $sys;
}

sub sysctl_data {
	eval $start if $b_log;
	my ($cpu,@line,%speeds,@working);
	my ($sep) = ('');
	my ($die_holder,$die_id,$phys_holder,$phys_id,$proc_count,$speed) = (0,0,0,0,0,0,0);
	set_cpu_data(\$cpu);
	@{$sysctl{'cpu'}} = () if !$sysctl{'cpu'}; # don't want error next!
	foreach (@{$sysctl{'cpu'}}){
		@line = split(/\s*:\s*/, $_);
		next if !$line[0];
		# darwin shows machine, like MacBook7,1, not cpu
		# machdep.cpu.brand_string: Intel(R) Core(TM)2 Duo CPU     P8600  @ 2.40GHz
		if (($bsd_type ne 'darwin' && $line[0] eq 'hw.model') || 
		$line[0] eq 'machdep.cpu.brand_string'){
			# cut L2 cache/cpu max speed out of model string, if available
			# openbsd 5.6: AMD Sempron(tm) Processor 3400+ ("AuthenticAMD" 686-class, 256KB L2 cache)
			# openbsd 6.x has Lx cache data in dmesg.boot
			# freebsd 10: hw.model: AMD Athlon(tm) II X2 245 Processor
			$line[1] = main::clean($line[1]);
			$line[1] = clean_cpu($line[1]);
			if ($line[1] =~ /([0-9]+)[\s-]*([KM]B)\s+L2 cache/i){
				my $multiplier = ($2 eq 'MB') ? 1024: 1;
				$cpu->{'l2-cache'} = $1 * $multiplier;
			}
			if ($line[1] =~ /([^0-9\.][0-9\.]+)[\s-]*[MG]Hz/){
				$cpu->{'max-freq'} = $1;
				if ($cpu->{'max-freq'} =~ /MHz/i){
					$cpu->{'max-freq'} =~ s/[\s-]*MHz//;
					$cpu->{'max-freq'} = clean_speed($cpu->{'max-freq'},'mhz');
				}
				elsif ($cpu->{'max-freq'} =~ /GHz/){
					$cpu->{'max-freq'} =~ s/[\s-]*GHz//i;
					$cpu->{'max-freq'} = $cpu->{'max-freq'} / 1000;
					$cpu->{'max-freq'} = clean_speed($cpu->{'max-freq'},'mhz');
				}
			}
			if ($line[1] =~ /\)$/){
				$line[1] =~ s/\s*\(.*\)$//;
			}
			$cpu->{'model_name'} = $line[1];
			$cpu->{'type'} = cpu_vendor($line[1]);
		}
		# NOTE: hw.l1icachesize: hw.l1dcachesize: ; in bytes, apparently
		elsif ($line[0] eq 'hw.l1dcachesize'){
			$cpu->{'l1d-cache'} = $line[1]/1024;
		}
		elsif ($line[0] eq 'hw.l1icachesize'){
			$cpu->{'l1i-cache'} = $line[1]/1024;
		}
		elsif ($line[0] eq 'hw.l2cachesize'){
			$cpu->{'l2-cache'} = $line[1]/1024;
		}
		elsif ($line[0] eq 'hw.l3cachesize'){
			$cpu->{'l3-cache'} = $line[1]/1024;
		}
		# hw.smt: openbsd
		elsif ($line[0] eq 'hw.smt'){
			$cpu->{'smt'} = ($line[1]) ? 'enabled' : 'disabled';
		}
		# htl: maybe freebsd, never seen, 1 is disabled, sigh...
		elsif ($line[0] eq 'machdep.hlt_logical_cpus'){
			$cpu->{'smt'} = ($line[1]) ? 'disabled' : 'enabled';
		}
		# this is in mghz in samples
		elsif (!$cpu->{'cur-freq'} && 
		 ($line[0] eq 'hw.clockrate' || $line[0] eq 'hw.cpuspeed')){
			$cpu->{'cur-freq'} = $line[1];
		}
		# these are in hz: 2400000000
		elsif ($line[0] eq 'hw.cpufrequency'){
			$cpu->{'cur-freq'} = $line[1]/1000000;
		}
		elsif ($line[0] eq 'hw.busfrequency_min'){
			$cpu->{'min-freq'} = $line[1]/1000000;
		}
		elsif ($line[0] eq 'hw.busfrequency_max'){
			$cpu->{'max-freq'} = $line[1]/1000000;
		}
		# FB seems to call freq something other than clock speed, unreliable 
		# eg: 1500 Mhz real shows as 2400 freq, which is wrong
		# elsif ($line[0] =~ /^dev\.cpu\.([0-9]+)\.freq$/){
		#	 $speed = clean_speed($line[1]);
		#	 $cpu->{'processors'}->[$1] = $speed;
		# }
		# weird FB thing, freq can be wrong, so just count the cores and call it 
		# done.
		elsif ($line[0] =~ /^dev\.cpu\.([0-9]+)\./ && 
			(!$cpu->{'processors'} || !defined $cpu->{'processors'}->[$1])){
			$cpu->{'processors'}->[$1] = undef;
		}
		elsif ($line[0] eq 'machdep.cpu.vendor'){
			$cpu->{'type'} = cpu_vendor($line[1]);
		}
		# darwin only?
		elsif ($line[0] eq 'machdep.cpu.features'){
			$cpu->{'flags'} = lc($line[1]);
		}
		# is this per phys or total?
		elsif ($line[0] eq 'hw.ncpu'){
			$cpu->{'cores'} = $line[1];
		}
		# Freebsd does some voltage hacking to actually run at lowest listed 
		# frequencies. The cpu does not actually support all the speeds output 
		# here but works in freebsd. Disabled this, the freq appear to refer to 
		# something else, not cpu clock. Remove XXX to enable
		elsif ($line[0] eq 'dev.cpu.0.freq_levelsXXX'){
			$line[1] =~ s/^\s+|\/[0-9]+|\s+$//g;
			if ($line[1] =~ /[0-9]+\s+[0-9]+/){
				# get rid of -1 in FB: 2400/-1 2200/-1 2000/-1 1800/-1
				$line[1] =~ s|/-1||g;
				my @temp = split(/\s+/, $line[1]);
				$cpu->{'max-freq'} = $temp[0];
				$cpu->{'min-freq'} = $temp[-1];
				$cpu->{'scalings'} = \@temp;
			}
		}
		# Disabled w/XXX. this is almost certainly bad data, should not be used
		elsif (!$cpu->{'cur-freq'} && $line[0] eq 'dev.cpu.0.freqXXX'){
			$cpu->{'cur-freq'} = $line[1];
		}
		# the following have only been seen in DragonflyBSD data but thumbs up!
		elsif ($line[0] eq 'hw.cpu_topology.members'){
			my @temp = split(/\s+/, $line[1]);
			my $count = scalar @temp;
			$count-- if $count > 0;
			# no way to get per processor speeds yet, so assign 0 to each
			foreach (0 .. $count){
				$cpu->{'processors'}->[$_] = 0;
			}
		}
		elsif ($line[0] eq 'hw.cpu_topology.cpu1.physical_siblings'){
			# string, like: cpu0 cpu1
			my @temp = split(/\s+/, $line[1]);
			$cpu->{'siblings'} = scalar @temp;
		}
		# increment by 1 for every new physical id we see. These are in almost all 
		# cases separate cpus, not separate dies within a single cpu body.
		# This needs DATA!! Almost certainly wrong!!
		elsif ($line[0] eq 'hw.cpu_topology.cpu0.physical_id'){
			if ($phys_holder != $line[1]){
				$phys_id++;
				$phys_holder = $line[1];
				push(@{$cpu->{'ids'}->[$phys_id][$die_id]},0);
			}
		}
		elsif ($line[0] eq 'hw.cpu_topology.cpu0.core_id'){
			$cpu->{'ids'}->[$phys_id][$line[1]] = $speed;
		}
	}
	if (!$cpu->{'flags'} || !$cpu->{'family'}){
		my $dmesg_boot = dboot_data();
		 # this core count may fix failed MT detection.
		$cpu->{'cores'} = $dmesg_boot->{'cores'} if $dmesg_boot->{'cores'};
		$cpu->{'flags'} = $dmesg_boot->{'flags'} if !$cpu->{'flags'};
		$cpu->{'family'} = $dmesg_boot->{'family'} if !$cpu->{'family'};
		$cpu->{'l1d-cache'} = $dmesg_boot->{'l1d-cache'} if !$cpu->{'l1d-cache'};
		$cpu->{'l1i-cache'} = $dmesg_boot->{'l1i-cache'} if !$cpu->{'l1i-cache'};
		$cpu->{'l2-cache'} = $dmesg_boot->{'l2-cache'} if !$cpu->{'l2-cache'};
		$cpu->{'l3-cache'} = $dmesg_boot->{'l3-cache'} if !$cpu->{'l3-cache'};
		$cpu->{'microcode'} = $dmesg_boot->{'microcode'} if !$cpu->{'microcode'};
		$cpu->{'model-id'} = $dmesg_boot->{'model-id'} if !$cpu->{'model-id'};
		$cpu->{'max-freq'} = $dmesg_boot->{'max-freq'} if !$cpu->{'max-freq'};
		$cpu->{'min-freq'} = $dmesg_boot->{'min-freq'} if !$cpu->{'min-freq'};
		$cpu->{'scalings'} = $dmesg_boot->{'scalings'} if !$cpu->{'scalings'};
		$cpu->{'siblings'} = $dmesg_boot->{'siblings'} if !$cpu->{'siblings'};
		$cpu->{'stepping'} = $dmesg_boot->{'stepping'} if !$cpu->{'stepping'};
		$cpu->{'type'} = $dmesg_boot->{'type'} if !$cpu->{'type'};
	}
	main::log_data('dump','%$cpu',$cpu) if $b_log;
	print Data::Dumper::Dumper $cpu if $dbg[8];
	eval $end if $b_log;
	return $cpu;
}

## DATA GENERATOR DATA SOURCES ##
sub dboot_data {
	eval $start if $b_log;
	my ($max_freq,$min_freq,@scalings);
	my ($family,$flags,$microcode,$model,$sep,$stepping,$type) = ('','','','','','','');
	my ($cores,$siblings) = (0,0);
	my ($l1d,$l1i,$l2,$l3) = (0,0,0,0);
	# this will be null if it was not readable
	my $file = $system_files{'dmesg-boot'};
	if ($dboot{'cpu'}){
		foreach (@{$dboot{'cpu'}}){
			# can be ~Features/Features2/AMD Features
			if (/Features/ || ($bsd_type eq "openbsd" && 
			 /^cpu0:\s*[a-z0-9]{2,3}(\s|,)[a-z0-9]{2,3}(\s|,)/i)){
				my @line = split(/:\s*/, lc($_));
				# free bsd has to have weird syntax: <....<b23>,<b34>>
				# Features2=0x1e98220b<SSE3,PCLMULQDQ,MON,SSSE3,CX16,SSE4.1,SSE4.2,POPCNT,AESNI,XSAVE,OSXSAVE,AVX>
				$line[1] =~ s/^[^<]*<|>[^>]*$//g;
				# then get rid of <b23> stuff
				$line[1] =~ s/<[^>]+>//g;
				# handle corner case like ,EL3 32,
				$line[1] =~ s/ (32|64)/_$1/g;
				# and replace commas with spaces
				$line[1] =~ s/,/ /g;
				$flags .= $sep . $line[1];
				$sep = ' ';
			}
			# cpu0:AMD E1-1200 APU with Radeon(tm) HD Graphics, 1398.66 MHz, 14-02-00
			elsif (/^cpu0:\s*([^,]+),\s+([0-9\.]+\s*MHz),\s+([0-9a-f]+)-([0-9a-f]+)-([0-9a-f]+)/){
				$type = cpu_vendor($1);
				$family = uc($3);
				$model =  uc($4);
				$stepping = uc($5);
				$family =~ s/^0//;
				$model =~ s/^0//;
				$stepping =~ s/^0//; # can be 00
			}
			# note: cpu cache is in KiB MiB even though they call it KB and MB
			# cpu31: 32KB 64b/line 8-way I-cache, 32KB 64b/line 8-way D-cache, 512KB 64b/line 8-way L2 cache
			# 8-way means 1 per core, 16-way means 1/2 per core
			elsif (/^cpu0:\s*[0-9\.]+[KMG]B\s/){
				# cpu0: 32KB 64b/line 4-way L1 VIPT I-cache, 32KB 64b/line 4-way L1 D-cache
				# cpu0:48KB 64b/line 3-way L1 PIPT I-cache, 32KB 64b/line 2-way L1 D-cache
				if (/\b([0-9\.]+[KMG])i?B\s\S+\s([0-9]+)-way\sD[\s-]?cache/){
					$l1d = main::translate_size($1);
				}
				if (/\b([0-9\.]+[KMG])i?B\s\S+\s([0-9]+)-way\s(L1 \S+\s)?I[\s-]?cache/){
					$l1i = main::translate_size($1);
				}
				if (/\b([0-9\.]+[KMG])i?B\s\S+\s([0-9]+)-way\sL2[\s-]?cache/){
					$l2 = main::translate_size($1);
				}
				if (/\b([0-9\.]+[KMG])i?B\s\S+\s([0-9]+)-way\sL3[\s-]?cache/){
					$l3 = main::translate_size($1);
				}
			}
			elsif (/^~Origin:(.+?)[\s,]+(Id|Family|Model|Stepping)/){
				$type = cpu_vendor($1);
				if (/\bId\s*=\s*(0x)?([0-9a-f]+)\b/){
					$microcode = ($1) ? uc($2) : $2;
				}
				if (/\bFamily\s*=\s*(0x)?([a-f0-9]+)\b/){
					$family = ($1) ? uc($2) : $2;
				}
				if (/\bModel\s*=\s*(0x)?([a-f0-9]+)\b/){
					$model = ($1) ? uc($2) : $2;
				}
				# they don't seem to use hex for steppings, so convert it
				if (/\bStepping\s*=\s*(0x)?([0-9a-f]+)\b/){
					$stepping = (!$1) ? uc(sprintf("%X",$2)) : $2;
				}
			}
			elsif (/^cpu0:.*?[0-9\.]+\s?MHz:\sspeeds:\s(.*?)\s?MHz/){
				@scalings = split(/[,\s]+/,$1);
				$min_freq = $scalings[-1];
				$max_freq = $scalings[0];
			}
			# 2 core MT Intel Core/Rzyen similar, use smt 0 as trigger to count:
			# cpu2:smt 0, core 1, package 0
			# cpu3:smt 1, core 1, package 0
			## but: older AMD Athlon 2 core:
			# cpu0:smt 0, core 0, package 0
			# cpu0:smt 0, core 0, package 1
			elsif (/cpu([0-9]+):smt\s([0-9]+),\score\s([0-9]+)(,\spackage\s([0-9]+))?/){
				$siblings = $1 + 1;
				$cores += 1 if $2 == 0;
			}
		}
		if ($flags){
			$flags =~ s/\s+/ /g;
			$flags =~ s/^\s+|\s+$//g;
		}
	}
	else {
		if ($file && ! -r $file){
			$flags = main::message('dmesg-boot-permissions');
		}
	}
	my $values = {
	'cores' => $cores,
	'family' => $family,
	'flags' => $flags,
	'l1d-cache' => $l1d,
	'l1i-cache' => $l1i,
	'l2-cache' => $l2,
	'l3-cache' => $l3,
	'max-freq' => $max_freq,
	'microcode' => $microcode,
	'min-freq' => $min_freq,
	'model-id' => $model,
	'scalings' => \@scalings,
	'siblings' => $siblings,
	'stepping' => $stepping,
	'type' => $type,
	};
	print Data::Dumper::Dumper $values if $dbg[27];
	eval $end if $b_log;
	return $values;
}

sub dmidecode_data {
	eval $start if $b_log;
	my $dmi_data = {'L1' => 0, 'L2' => 0,'L3' => 0, 'phys-cnt' => 0,
	'ext-clock' => undef, 'socket' => undef, 'speed' => undef, 
	'max-speed' => undef, 'upgrade' => undef, 'volts' => undef};
	return $dmi_data if !@dmi;
	my ($id,$amount,$socket,$upgrade);
	foreach my $item (@dmi){
		next if ref $item ne 'ARRAY';
		next if ($item->[0] < 4 || $item->[0] == 5 || $item->[0] == 6);
		last if $item->[0] > 7;
		if ($item->[0] == 7){
			# skip first three rows, we don't need that data
			# seen very bad data, L2 labeled L3, and random phantom type 7 caches
			($id,$amount) = ('',0);
			# Configuration: Disabled, Not Socketed, Level 2
			next if $item->[4] =~ /^Configuration:.*Disabled/i;
			# labels have to be right before the block, otherwise exiting sub errors
			DMI: 
			foreach my $value (@$item[3 .. $#$item]){
				next if $value =~ /^~/;
				# variants: L3 - Cache; L3 Cache; L3-cache; L2 CACHE; CPU Internal L1
				if ($value =~ /^Socket Designation:.*? (L[1-3])\b/){
					$id = lc($1);
				}
				# some cpus only show Socket Designation: Internal cache
				elsif (!$id && $value =~ /^Configuration:.* Level.*?([1-3])\b/){
					if ($value !~ /Disabled/i){
						$id = "l$1";
					}
				}
				# NOTE: cache is in KiB or MiB but they call it kB or MB
				# so we send translate_size k or M which trips KiB/MiB mode
				# if disabled can be 0.
				elsif ($id && $value =~ /^Installed Size:\s+(.*?[kKM])i?B$/){
					# Config..Disabled test should have gotten this, but just in case 0 size
					next DMI if !$1; 
					$amount = main::translate_size($1);
					}
				if ($id && $amount){
					$dmi_data->{$id} = $amount;
					last;
				}
			}
		}
		# note: for multi cpu systems, we're hoping that these values are
		# the same for each cpu, which in most pc situations they will be,
		# and most ARM etc won't be using dmi data here anyway.
		# Older dmidecode appear to have unreliable Upgrade outputs
		elsif ($item->[0] == 4){
			# skip first three row,s we don't need that data
			($socket,$upgrade) = ();
			$dmi_data->{'phys-cnt'}++; # try to catch bsds without physical cpu count
			foreach my $value (@$item[3 .. $#$item]){
				next if $value =~ /^~/;
				# note: on single cpu systems, Socket Designation shows socket type,
				# but on multi, shows like, CPU1; CPU Socket #2; Socket 0; so check values a bit.
				# Socket Designation: Intel(R) Core(TM) i5-3470 CPU @ 3.20GHz
				# Sometimes shows as CPU Socket...
				if ($value =~ /^Socket Designation:\s*(CPU\s*Socket|Socket)?[\s-]*(.*)$/i){
					$upgrade = main::clean_dmi($2) if $2 !~ /(cpu|[mg]hz|onboard|socket|@|^#?[0-9]$)/i;
					# print "$socket_temp\n";
				}
				# normally we prefer this value, but sometimes it's garbage
				# older systems often show: Upgrade: ZIF Socket which is a generic term, legacy
				elsif ($value =~ /^Upgrade:\s*(CPU\s*Socket|Socket)?[\s-]*(.*)$/i){
					# print "$2\n";
					$socket = main::clean_dmi($2) if $2 !~ /(ZIF|\bslot\b)/i;
				}
				# seen: Voltage: 5.0 V 2.9 V
				elsif ($value =~ /^Voltage:\s*([0-9\.]+)\s*(V|Volts)?\b/i){
					$dmi_data->{'volts'} = main::clean_dmi($1);
				}
				elsif ($value =~ /^Current Speed:\s*([0-9\.]+)\s*([MGK]Hz)?\b/i){
					$dmi_data->{'speed'} = main::clean_dmi($1);
				}
				elsif ($value =~ /^Max Speed:\s*([0-9\.]+)\s*([MGK]Hz)?\b/i){
					$dmi_data->{'max-speed'} = main::clean_dmi($1);
				}
				elsif ($value =~ /^External Clock:\s*([0-9\.]+\s*[MGK]Hz)\b/){
					$dmi_data->{'ext-clock'} = main::clean_dmi($1);
				}
			}
		}
	}
	# Seen older cases where Upgrade: Other value exists
	if ($socket || $upgrade){
		if ($socket && $upgrade){
			undef $upgrade if $socket eq $upgrade;
		}
		elsif ($upgrade){
			$socket = $upgrade;
			undef $upgrade;
		}
		$dmi_data->{'socket'} = $socket;
		$dmi_data->{'upgrade'} = $upgrade;
	}
	main::log_data('dump','%$dmi_data',$dmi_data) if $b_log;
	print Data::Dumper::Dumper $dmi_data if $dbg[27];
	eval $end if $b_log;
	return $dmi_data;
}

## CPU PROPERTIES MAIN ##
sub cpu_properties {
	my ($cpu) = @_;
	my ($cpu_sys,$arch_level);
	my $dmi_data = {};
	my $tests = {};
	my $caches = {
	'cache' => 0, # general, non id'ed from cpuinfo generic cache
	'l1' => 0,
	'l1d' => 0,
	'l1i' => 0,
	'l2' => 0,
	'l3' => 0,
	};
	my $counts = {
	'dies' => 0,
	'cpu-cores' => 0,
	'cores' => 0,
	'cores-multiplier' => 0,
	'physical' => 0,
	'processors' => 0,
	};
	my ($cache_check) = ('');
	if (!$bsd_type && -d '/sys/devices' && !$force{'cpuinfo'}){
		$cpu_sys = cpu_sys_data($cpu->{'sys-freq'});
	}
	cp_test_types($cpu,$tests) if $cpu->{'type'};
	undef $cpu_sys if $dbg[42];
	## START CPU DATA HANDLERS ##
	if (defined $cpu_sys->{'cpus'}){
		cp_data_sys(
		$cpu,
		$cpu_sys,
		$caches,
		$counts
		);
	}
	if (!defined $cpu_sys->{'cpus'} || !$counts->{'physical'} || 
	 !$counts->{'cpu-cores'}){
		cp_data_fallback(
		$cpu,
		$caches,
		\$cache_check,
		$counts,
		$tests,
		);
	}
	# some arm cpus report each core as its own die, but that's wrong
	if (%risc && $counts->{'dies'} > 1 && 
	$counts->{'cpu-cores'} == $counts->{'dies'}){
		$counts->{'dies'} = 1;
		$cpu->{'dies'} = 1;
	}
	if ($type eq 'full' && ($extra > 1 || ($bsd_type && !$cpu->{'l2-cache'}))){
		cp_data_dmi(
		$cpu,
		$dmi_data,
		$caches,
		$counts, # only to set BSD phys cpu counts if not found
		\$cache_check,
		);
	}
	## END CPU DATA HANDLERS ##
	
	# print "pc: $counts{'processors'} s: $cpu->{'siblings'} cpuc: $counts{'cpu-cores'} corec: $counts{'cores'}\n";
	
	## START CACHE PROCESSING ##
	# Get BSD and legacy linux caches if not already from dmidecode or cpu_sys.
	if ($type eq 'full' && 
	!$caches->{'l1'} && !$caches->{'l2'} && !$caches->{'l2'}){
		cp_caches_fallback(
		$counts,
		$cpu,
		$caches,
		\$cache_check,
		);
	}
	# nothing to check!
	if ($type eq 'full'){
		if (!$caches->{'l1'} && !$caches->{'l2'} && !$caches->{'l3'} && 
		!$caches->{'cache'}){
			$cache_check = '';
		}
		if ($caches->{'cache'}){
			# we don't want any math done on this one, who knows what it is
			$caches->{'cache'} = cp_cache_processor($caches->{'cache'},1);
		}
		if ($caches->{'l1'}){
			$caches->{'l1'} = cp_cache_processor($caches->{'l1'},$counts->{'physical'});
		}
		if ($caches->{'l2'}){
			$caches->{'l2'} = cp_cache_processor($caches->{'l2'},$counts->{'physical'});
		}
		if ($caches->{'l3'}){
			$caches->{'l3'} = cp_cache_processor($caches->{'l3'},$counts->{'physical'});
		}
	}
	## END CACHE PROCESSING ##
	
	## START TYPE/LAYOUT/ARCH/BUGS ##
	my ($cpu_type) = ('');
	$cpu_type = cp_cpu_type(
	$counts,
	$cpu,
	$tests
	);
	my $topology = {};
	cp_cpu_topology($counts,$topology);
	my $arch = cp_cpu_arch(
	$cpu->{'type'},
	$cpu->{'family'},
	$cpu->{'model-id'},
	$cpu->{'stepping'},
	$cpu->{'model_name'},
	);
	# arm cpuinfo case only; confirm on bsds, not sure all get family/ids
	if ($arch->[0] && !$cpu->{'arch'}){
		($cpu->{'arch'},$cpu->{'arch-note'},$cpu->{'process'},$cpu->{'gen'},
		$cpu->{'year'}) = @$arch;
	}
	# cpu_arch comes from set_os()
	if (!$cpu->{'arch'} && $cpu_arch && %risc){
		$cpu->{'arch'} = $cpu_arch;
	}
	if ($b_admin && defined $cpu_sys->{'data'}{'vulnerabilities'}){
		$cpu->{'bugs-hash'} = $cpu_sys->{'data'}{'vulnerabilities'};
	}
	## END TYPE/LAYOUT/ARCH/BUGS ##
	
	## START SPEED/BITS ##
	my $speed_info = cp_speed_data($cpu,$cpu_sys);
	# seen case where 64 bit cpu with lm flag shows as i686 (tinycore)
 	if (!%risc && $cpu->{'flags'} && (!$bits_sys || $bits_sys == 32)){
		$bits_sys = ($cpu->{'flags'} =~ /\blm\b/) ? 64 : 32;
	}
	# must run after to make sure we have cpu bits
	if ($b_admin && !%risc && $bits_sys && $bits_sys == 64 && $cpu->{'flags'}){
		$arch_level = cp_cpu_level(
		$cpu->{'flags'}
		);
	}
	## END SPEED/BITS ##
	
	## LOAD %cpu_properties
	my $cpu_properties = {
	'arch-level' => $arch_level,
	'avg-speed-key' => $speed_info->{'avg-speed-key'},
	'bits-sys' => $bits_sys,
	'cache' => $caches->{'cache'},
	'cache-check' => $cache_check,
	'cpu-type' => $cpu_type,
	'dmi-max-speed' => $dmi_data->{'max-speed'},
	'dmi-speed' => $dmi_data->{'speed'},
	'ext-clock' => $dmi_data->{'ext-clock'},
	'high-speed-key' => $speed_info->{'high-speed-key'},
	'l1-cache' => $caches->{'l1'},
	'l1d-desc' => $caches->{'l1d-desc'},
	'l1i-desc' => $caches->{'l1i-desc'},
	'l2-cache' => $caches->{'l2'},
	'l2-desc' => $caches->{'l2-desc'},
	'l3-cache' => $caches->{'l3'},
	'l3-desc' => $caches->{'l3-desc'},
	'min-max-key' => $speed_info->{'min-max-key'},
	'min-max' => $speed_info->{'min-max'},
	'socket' => $dmi_data->{'socket'},
	'scaling-min-max-key' => $speed_info->{'scaling-min-max-key'},
	'scaling-min-max' => $speed_info->{'scaling-min-max'},
	'speed-key' => $speed_info->{'speed-key'},
	'speed' => $speed_info->{'speed'},
	'topology-full' => $topology->{'full'},
	'topology-string' => $topology->{'string'},
	'upgrade' => $dmi_data->{'upgrade'},
	'volts' => $dmi_data->{'volts'},
	};
	if ($b_log){
		main::log_data('dump','%$cpu_properties',$cpu_properties);
		main::log_data('dump','%$topology',$topology);
	}
	# print Data::Dumper::Dumper $cpu;
	if ($dbg[38]){
		print Data::Dumper::Dumper $cpu_properties;
		print Data::Dumper::Dumper $topology;
	}
	# my $dc = scalar @dies;
	# print 'phys: ' . $pc . ' dies: ' . $dc, "\n";
	eval $end if $b_log;
	return $cpu_properties;
}

## CPU DATA ENGINES ##
# everything is passed by reference so no need to return anything
sub cp_data_dmi {
	eval $start if $b_log;
	my ($cpu,$dmi_data,$caches,$counts,$cache_check) = @_;
	my $cpu_dmi = dmidecode_data();
	# fix for bsds that do not show physical cpus, like openbsd
	if ($cpu_dmi->{'phys-cnt'} && $counts->{'physical'} == 1 && 
	 $cpu_dmi->{'phys-cnt'} > 1){
		$counts->{'physical'} = $cpu_dmi->{'phys-cnt'};
	}
	# We have to undef all the sys stuff to get back to the true dmidecode results
	# Too many variants to treat one by one, just clear it out if forced.
	undef $caches if $force{'dmidecode'};
	# We don't want to use dmi L1/L2/L3 at all for non BSD systems unless forced
	# because have seen totally gibberish dmidecode data for caches. /sys cache 
	# data preferred, more granular and basically consistently right.
	# Only run for linux if no cache data found, but BSD use to fill in missing
	# (we don't care about legacy errors for BSD since the data isn't adequate).
	# legacy dmidecode cache data used the per cache value, NOT the per CPU total 
	# value like it does today. Which makes it impossible to know for sure if the 
	# given value is right (new, or if cache matched cpu total) or inadequate.
	if ((!$bsd_type && !$caches->{'l1'} && !$caches->{'l2'} && !$caches->{'l3'}) ||
	($bsd_type && (!$caches->{'l1'} || !$caches->{'l2'} || !$caches->{'l3'}))){
		# Newer dmi: cache type total per phys cpu; Legacy: raw cache size only
		if ($cpu_dmi->{'l1'} && !$caches->{'l1'}){
			$caches->{'l1'} = $cpu_dmi->{'l1'};
			$$cache_check = main::message('note-check');
		}
		# note: bsds often won't have L2 catch data found yet, but bsd sysctl can 
		# have these values so let's check just in case. OpenBSD does have it often.
		if ($cpu_dmi->{'l2'} && !$caches->{'l2'}){
			$caches->{'l2'} = $cpu_dmi->{'l2'};
			$$cache_check = main::message('note-check');
		}
		if ($cpu_dmi->{'l3'} && !$caches->{'l3'}){
			$caches->{'l3'} = $cpu_dmi->{'l3'};
			$$cache_check = main::message('note-check');
		}
	}
	$dmi_data->{'max-speed'} = $cpu_dmi->{'max-speed'};
	$dmi_data->{'socket'} = $cpu_dmi->{'socket'} if $cpu_dmi->{'socket'};
	$dmi_data->{'upgrade'} = $cpu_dmi->{'upgrade'} if $cpu_dmi->{'upgrade'};
	$dmi_data->{'speed'} = $cpu_dmi->{'speed'} if $cpu_dmi->{'speed'};
	$dmi_data->{'ext-clock'} = $cpu_dmi->{'ext-clock'} if $cpu_dmi->{'ext-clock'};
	$dmi_data->{'volts'} = $cpu_dmi->{'volts'} if $cpu_dmi->{'volts'};
	eval $end if $b_log;
}

sub cp_data_fallback {
	eval $start if $b_log;
	my ($cpu,$caches,$cache_check,$counts,$tests) = @_;
	if (!$counts->{'physical'}){
		# handle case where cpu reports say, phys id 0, 2, 4, 6
		foreach (@{$cpu->{'ids'}}){
			$counts->{'physical'}++ if $_;
		}
	}
	# count unique processors ##
	# note, this fails for intel cpus at times
	# print ref $cpu->{'processors'}, "\n";
	if (!$counts->{'processors'}){
		$counts->{'processors'} = scalar @{$cpu->{'processors'}};
	}
	# print "p count:$counts->{'processors'}\n";
	# print Data::Dumper::Dumper $cpu->{'processors'};
	# $counts->{'cpu-cores'} is per physical cpu
	# note: elbrus supports turning off cores, so we need to add one for cases 
	# where rounds to 0 or 1 less
	# print "$cpu{'type'},$cpu{'family'},$cpu{'model-id'},$cpu{'arch'}\n";
	if ($tests->{'elbrus'} && $counts->{'processors'}){
		my $elbrus = cp_elbrus_data($cpu->{'family'},$cpu->{'model-id'},
		$counts->{'processors'},$cpu->{'arch'});
		$counts->{'cpu-cores'} = $elbrus->[0];
		$counts->{'physical'} = $elbrus->[1];
		$cpu->{'arch'} = $elbrus->[2];
		# print 'model id: ' . $cpu->{'model-id'} . ' arch: ' . $cpu->{'arch'} . " cpc: $counts->{'cpu-cores'} phyc: $counts->{'physical'} proc: $counts->{'processors'} \n";
	}
	$counts->{'physical'} ||= 1; # assume 1 if no id found, as with ARM
	foreach my $die_ref (@{$cpu->{'ids'}}){
		next if ref $die_ref ne 'ARRAY';
		$counts->{'cores'} = 0;
		$counts->{'dies'} = scalar @$die_ref;
		#$cpu->{'dies'} = $counts->{'dies'};
		foreach my $core_ref (@$die_ref){
			next if ref $core_ref ne 'ARRAY';
			$counts->{'cores'} = 0;# reset for each die!!
			# NOTE: the counters can be undefined because the index comes from 
			# core id: which can be 0 skip 1 then 2, which leaves index 1 undefined
			# risc cpus do not actually show core id so ignore that counter
			foreach my $id (@$core_ref){
				$counts->{'cores'}++ if defined $id && !%risc;
			}
			# print 'cores: ' . $counts->{'cores'}, "\n";
		}
	}
	# this covers potentially cases where ARM cpus have > 1 die 
	# maybe applies to all risc, not sure, but dies is broken anyway for cpuinfo
	if (!$cpu->{'dies'}){
		if ($risc{'arm'} && $counts->{'dies'} <= 1 && $cpu->{'dies'} > 1){
			$counts->{'dies'} = $cpu->{'dies'};
		}
		else {
			$cpu->{'dies'} = $counts->{'dies'};
		}
	}
	# this is an attempt to fix the amd family 15 bug with reported cores vs actual cores
	# NOTE: amd A6-4400M APU 2 core reports: cores: 1 siblings: 2
	# NOTE: AMD A10-5800K APU 4 core reports: cores: 2 siblings: 4
	if (!$counts->{'cpu-cores'}){
		if ($cpu->{'cores'} && !$counts->{'cores'} || 
		 $cpu->{'cores'} >= $counts->{'cores'}){
			$counts->{'cpu-cores'} = $cpu->{'cores'};
		}
		elsif ($counts->{'cores'} > $cpu->{'cores'}){
			$counts->{'cpu-cores'} = $counts->{'cores'};
		}
	}
	# print "cpu-c:$counts->{'cpu-cores'}\n";
	# $counts->{'cpu-cores'} = $cpu->{'cores'}; 
	# like, intel core duo
	# NOTE: sadly, not all core intel are HT/MT, oh well...
	# xeon may show wrong core / physical id count, if it does, fix it. A xeon
	# may show a repeated core id : 0 which gives a fake num_of_cores=1
	if ($tests->{'intel'}){
		if ($cpu->{'siblings'} && $cpu->{'siblings'} > 1 && 
		 $cpu->{'cores'} && $cpu->{'cores'} > 1){
			if ($cpu->{'siblings'}/$cpu->{'cores'} == 1){
				$tests->{'intel'} = 0;
				$tests->{'ht'} = 0;
			}
			else {
				$counts->{'cpu-cores'} = ($cpu->{'siblings'}/2); 
				$tests->{'ht'} = 1;
			}
		}
	}
	# ryzen is made out of blocks of 2, 4, or 8 core dies...
	if ($tests->{'ryzen'}){
		$counts->{'cpu-cores'} = $cpu->{'cores'}; 
		 # note: posix ceil isn't present in Perl for some reason, deprecated?
		my $working = $counts->{'cpu-cores'} / 8;
		my @temp = split('\.', $working);
		$cpu->{'dies'} = ($temp[1] && $temp[1] > 0) ? $temp[0]++ : $temp[0];
		$counts->{'dies'} = $cpu->{'dies'};
	}
	# these always have 4 dies
	elsif ($tests->{'epyc'}){
		$counts->{'cpu-cores'} = $cpu->{'cores'}; 
		$counts->{'dies'} = $cpu->{'dies'} = 4;
	}
	# final check, override the num of cores value if it clearly is wrong
	# and use the raw core count and synthesize the total instead of real count
	if ($counts->{'cpu-cores'} == 0 && 
	 $cpu->{'cores'} * $counts->{'physical'} > 1){
		$counts->{'cpu-cores'} = ($cpu->{'cores'} * $counts->{'physical'});
	}
	# last check, seeing some intel cpus and vms with intel cpus that do not show any
	# core id data at all, or siblings.
	if ($counts->{'cpu-cores'} == 0 && $counts->{'processors'} > 0){
		$counts->{'cpu-cores'} = $counts->{'processors'};
	}
	# this happens with BSDs which have very little cpu data available
	if ($counts->{'processors'} == 0 && $counts->{'cpu-cores'} > 0){
		$counts->{'processors'} = $counts->{'cpu-cores'};
		if ($bsd_type && ($tests->{'ht'} || $tests->{'amd-zen'}) && 
		 $counts->{'cpu-cores'} > 2){
			$counts->{'cpu-cores'} = $counts->{'cpu-cores'}/2;;
		}
		my $count = $counts->{'processors'};
		$count-- if $count > 0;
		$cpu->{'processors'}[$count] = 0;
		# no way to get per processor speeds yet, so assign 0 to each
		# must be a numeric value. Could use raw speed from core 0, but 
		# that would just be a hack.
		foreach (0 .. $count){
			$cpu->{'processors'}[$_] = 0;
		}
	}
	# so far only OpenBSD has a way to detect MT cpus, but Openbsd has disabled MT
	if ($bsd_type){
		if ($cpu->{'siblings'} && 
		 $counts->{'cpu-cores'} && $counts->{'cpu-cores'} > 1){
			$counts->{'cores-multiplier'} = $counts->{'cpu-cores'};
		}
		# if no siblings we couldn't get MT status of cpu so can't trust cache
		else {
			$$cache_check = main::message('note-check');
		}
	}
	# only elbrus shows L1 / L3 cache data in cpuinfo, cpu_sys data should show 
	# for newer full linux.
	elsif ($counts->{'cpu-cores'} &&
	 ($tests->{'elbrus'} || $counts->{'cpu-cores'} > 1)) {
		$counts->{'cores-multiplier'} = $counts->{'cpu-cores'};
	}
	# last test to catch some corner cases 
	# seen a case where a xeon vm in a dual xeon system actually had 2 cores, no MT
	# so it reported 4 siblings, 2 cores, but actually only had 1 core per virtual cpu
	# print "prc: $counts->{'processors'} phc: $counts->{'physical'} coc: $counts->{'cores'} cpc: $counts->{'cpu-cores'}\n";
	# this test was for arm but I think it applies to all risc, but risc will be sys
	if (!%risc && 
	 $counts->{'processors'} == $counts->{'physical'} * $counts->{'cores'} && 
	 $counts->{'cpu-cores'} > $counts->{'cores'}){
		$tests->{'ht'} = 0;
		# $tests->{'xeon'} = 0;
		$tests->{'intel'} = 0;
		$counts->{'cpu-cores'} = 1;
		$counts->{'cores'} = 1;
		$cpu->{'siblings'} = 1;
	}
	eval $end if $b_log;
}

# all values passed by reference so no need for returns
sub cp_data_sys {
	eval $start if $b_log;
	my ($cpu,$cpu_sys,$caches,$counts) = @_;
	my (@keys) = (sort keys %{$cpu_sys->{'cpus'}});
	return if !@keys;
	$counts->{'physical'} = scalar @keys;
	if ($type eq 'full' && $cpu_sys->{'cpus'}{$keys[0]}{'caches'}){
		cp_sys_caches($cpu_sys->{'cpus'}{$keys[0]}{'caches'},$caches,'l1','l1d');
		cp_sys_caches($cpu_sys->{'cpus'}{$keys[0]}{'caches'},$caches,'l1','l1i');
		cp_sys_caches($cpu_sys->{'cpus'}{$keys[0]}{'caches'},$caches,'l2','');
		cp_sys_caches($cpu_sys->{'cpus'}{$keys[0]}{'caches'},$caches,'l3','');
	}
	if ($cpu_sys->{'data'}{'speeds'}{'all'}){
		$counts->{'processors'} = scalar @{$cpu_sys->{'data'}{'speeds'}{'all'}};
	}
	if (defined $cpu_sys->{'data'}{'smt-active'}){
		if ($cpu_sys->{'data'}{'smt-active'}){
			$cpu->{'smt'} = 'enabled';
		}
		# values: on/off/notsupported/notimplemented
		elsif (defined $cpu_sys->{'data'}{'smt-control'} &&
		 $cpu_sys->{'data'}{'smt-control'} =~ /^not/){
			$cpu->{'smt'} = main::message('unsupported');
		}
		else {
			$cpu->{'smt'} = 'disabled';
		}
	}
	my $i = 0;
	my (@governor,@max,@min,@phys_cores);
	foreach my $phys_id (@keys){
		if ($cpu_sys->{'cpus'}{$phys_id}{'cores'}){
			my ($mt,$st) = (0,0);
			my (@core_keys) = keys %{$cpu_sys->{'cpus'}{$phys_id}{'cores'}};
			$cpu->{'cores'} = $counts->{'cpu-cores'} = scalar @core_keys;
			$counts->{'cpu-topo'}[$i]{'cores'} = $cpu->{'cores'};
			if ($cpu_sys->{'cpus'}{$phys_id}{'dies'}){
				$counts->{'cpu-topo'}[$i]{'dies'} = scalar @{$cpu_sys->{'cpus'}{$phys_id}{'dies'}};
				$cpu->{'dies'} = $counts->{'cpu-topo'}[$i]{'dies'};
			}
			# If we ever get > 1 min/max speed per phy cpu, we'll need to fix the [0]
			if ($cpu_sys->{'cpus'}{$phys_id}{'max-freq'}[0]){
				if (!grep {$cpu_sys->{'cpus'}{$phys_id}{'max-freq'}[0] eq $_} @max){
					push(@max,$cpu_sys->{'cpus'}{$phys_id}{'max-freq'}[0]);
				}
				$counts->{'cpu-topo'}[$i]{'max'} = $cpu_sys->{'cpus'}{$phys_id}{'max-freq'}[0];
			}
			if ($cpu_sys->{'cpus'}{$phys_id}{'min-freq'}[0]){
				if (!grep {$cpu_sys->{'cpus'}{$phys_id}{'min-freq'}[0] eq $_} @min){
					push(@min,$cpu_sys->{'cpus'}{$phys_id}{'min-freq'}[0]);
				}
				$counts->{'cpu-topo'}[$i]{'min'} = $cpu_sys->{'cpus'}{$phys_id}{'min-freq'}[0];
			}
			# cheating, this is not a count, but we need the data for topology, must
			# sort since governors can be in different order if > 1
			if ($cpu_sys->{'cpus'}{$phys_id}{'governor'}){
				foreach my $gov (@{$cpu_sys->{'cpus'}{$phys_id}{'governor'}}){
					push(@governor,$gov) if !grep {$_ eq $gov} @governor;
				}
				$cpu->{'governor'} = join(',',@governor);
			}
			if ($cpu_sys->{'cpus'}{$phys_id}{'scaling-driver'}){
				$cpu->{'scaling-driver'} = $cpu_sys->{'cpus'}{$phys_id}{'scaling-driver'};
			}
			if ($cpu_sys->{'cpus'}{$phys_id}{'scaling-driver'}){
				$cpu->{'scaling-driver'} = $cpu_sys->{'cpus'}{$phys_id}{'scaling-driver'};
			}
			if ($cpu_sys->{'cpus'}{$phys_id}{'scaling-max-freq'}){
				$cpu->{'scaling-max-freq'} = $cpu_sys->{'cpus'}{$phys_id}{'scaling-max-freq'};
			}
			if ($cpu_sys->{'cpus'}{$phys_id}{'scaling-min-freq'}){
				$cpu->{'scaling-min-freq'} = $cpu_sys->{'cpus'}{$phys_id}{'scaling-min-freq'};
			}
			if (!grep {$counts->{'cpu-cores'} eq $_} @phys_cores){
				push(@phys_cores,$counts->{'cpu-cores'});
			}
			if ($counts->{'processors'}){
				if ($counts->{'processors'} > $counts->{'cpu-cores'}){
					for my $key (@core_keys){
						if ((my $threads = scalar @{$cpu_sys->{'cpus'}{$phys_id}{'cores'}{$key}}) > 1){
							$counts->{'cpu-topo'}[$i]{'cores-mt'}++;
							$counts->{'cpu-topo'}[$i]{'threads'} += $threads;
							# note: for mt+st type cpus, we need to handle tpc on output per type
							$counts->{'cpu-topo'}[$i]{'tpc'} = $threads;
							$counts->{'struct-mt'} = 1;
						}
						else {
							$counts->{'cpu-topo'}[$i]{'cores-st'}++;
							$counts->{'cpu-topo'}[$i]{'threads'}++;
							$counts->{'struct-st'} = 1;
						}
					}
				}
			}
			$i++;
		}
	}
	$counts->{'struct-max'} = 1 if scalar @max > 1;
	$counts->{'struct-min'} = 1 if scalar @min > 1;
	$counts->{'struct-cores'} = 1 if scalar @phys_cores > 1;
	if ($b_log){
		main::log_data('dump','%cpu_properties',$caches);
		main::log_data('dump','%cpu_properties',$counts);
	}
	# print Data::Dumper::Dumper $caches;
	# print Data::Dumper::Dumper $counts;
	eval $end if $b_log;
}

sub cp_sys_caches {
	eval $start if $b_log;
	my ($sys_caches,$caches,$id,$id_di) = @_;
	my $cache_id = ($id_di) ? $id_di: $id;
	my %cache_desc;
	if ($sys_caches->{$cache_id}){
		# print Data::Dumper::Dumper $cpu_sys->{'cpus'};
		foreach (@{$sys_caches->{$cache_id}}){
			# android seen to have cache data without size item
			next if !defined $_; 
			$caches->{$cache_id} += $_;
			$cache_desc{$_}++ if $b_admin;
		}
		$caches->{$id} += $caches->{$id_di} if $id_di;
		$caches->{$cache_id . '-desc'} = cp_cache_desc(\%cache_desc) if $b_admin;
	}
	eval $end if $b_log;
}

## CPU PROPERTIES TOOLS ## 
sub cp_cache_desc {
	my ($cache_desc) = @_;
	my ($desc,$sep) = ('','');
	foreach (sort keys %{$cache_desc}){
		$desc .= $sep . $cache_desc->{$_} . 'x' . main::get_size($_,'string');
		$sep = ', ';
	}
	undef $cache_desc;
	return $desc;
}

# args: 0: $caches passed by reference
sub cp_cache_processor {
	my ($cache,$count) = @_;
	my $output;
	if ($count > 1){
		$output = $count . 'x ' . main::get_size($cache,'string');
		$output .= ' (' . main::get_size($cache * $count,'string') . ')';
	}
	else {
		$output = main::get_size($cache,'string');
	}
	# print "$cache :: $count :: $output\n";
	return $output;
}

sub cp_caches_fallback {
	eval $start if $b_log;
	my ($counts,$cpu,$caches,$cache_check) = @_;
	# L1 Cache
	if ($cpu->{'l1-cache'}){
		$caches->{'l1'} = $cpu->{'l1-cache'} * $counts->{'cores-multiplier'};
	}
	else {
		if ($cpu->{'l1d-cache'}){
			$caches->{'l1d-desc'} = $counts->{'cores-multiplier'} . 'x';
			$caches->{'l1d-desc'} .= main::get_size($cpu->{'l1d-cache'},'string');
			$caches->{'l1'} += $cpu->{'l1d-cache'} * $counts->{'cores-multiplier'};
		}
		if ($cpu->{'l1i-cache'}){
			$caches->{'l1i-desc'} = $counts->{'cores-multiplier'} . 'x';
			$caches->{'l1i-desc'} .= main::get_size($cpu->{'l1i-cache'},'string');
			$caches->{'l1'} += $cpu->{'l1i-cache'} * $counts->{'cores-multiplier'};
		}
	}
	# L2 Cache
	# If summed by dmidecode or from cpu_sys don't use this
	if ($cpu->{'l2-cache'}){
		# the only possible change for bsds is if dmidecode method gives phy counts
		# Looks like Intel on bsd shows L2 per core, not total. Note: Pentium N3540
		# uses 2(not 4)xL2 cache size for 4 cores, sigh... you just can't win...
		if ($bsd_type){
			$caches->{'l2'} = $cpu->{'l2-cache'} * $counts->{'cores-multiplier'};
		}
		# AMD SOS chips appear to report full L2 cache per cpu
		elsif ($cpu->{'type'} eq 'amd' && ($cpu->{'family'} eq '14' || 
		 $cpu->{'family'} eq '15' || $cpu->{'family'} eq '16')){
			$caches->{'l2'} = $cpu->{'l2-cache'};
		}
		elsif ($cpu->{'type'} ne 'intel'){
			$caches->{'l2'} = $cpu->{'l2-cache'} * $counts->{'cpu-cores'};
		}
		# note: this handles how intel reports L2, total instead of per core like 
		# AMD does when cpuinfo sourced, when caches sourced, is per core as expected
		else {
			$caches->{'l2'} = $cpu->{'l2-cache'};
		}
	}
	# l3 Cache - usually per physical cpu, but some rzyen will have per ccx. 
	if ($cpu->{'l3-cache'}){
		$caches->{'l3'} = $cpu->{'l3-cache'};
	}
	# don't do anything with it, we have no ideaw if it's L1, L2, or L3, generic
	# cpuinfo fallback, it's junk data essentially, and will show as cache:
	# only use this fallback if no cache data was found
	if ($cpu->{'cache'} && !$caches->{'l1'} && !$caches->{'l2'} && 
	 !$caches->{'l3'}){
		$caches->{'cache'} = $cpu->{'cache'};
		$$cache_check = main::message('note-check');
	}
	eval $end if $b_log;
}

## START CPU ARCH ##
sub cp_cpu_arch {
	eval $start if $b_log;
	my ($type,$family,$model,$stepping,$name) = @_;
	# we can get various random strings for rev/stepping, particularly for arm,ppc
	# but we want stepping to be integer for math comparisons, so convert, or set
	# to 0 so it won't break anything.
	if (defined $stepping && $stepping =~ /^[A-F0-9]{1,3}$/i){
		$stepping = hex($stepping);
	}
	else {
		$stepping = 0
	}
	$family ||= '';
	$model = '' if !defined $model; # model can be 0
	my ($arch,$gen,$note,$process,$year);
	my $check = main::message('note-check');
	# See: docs/inxi-cpu.txt 
	# print "type:$type fam:$family model:$model step:$stepping\n";
	# Note: AMD family is not Ext fam . fam but rather Ext-fam + fam.
	# But model is Ext model . model...
	if ($type eq 'amd'){
		if ($family eq '3'){
			$arch = 'Am386';
			$process = 'AMD 900-1500nm';
			$year = '1991-92';
		}
		elsif ($family eq '4'){
			if ($model =~ /^(3|7|8|9|A)$/){
				$arch = 'Am486';
				$process = 'AMD 350-700nm';
				$year = '1993-95';}
			elsif ($model =~ /^(E|F)$/){
				$arch = 'Am5x86';
				$process = 'AMD 350nm';
				$year = '1995-99';}
		}
		elsif ($family eq '5'){
			## verified
			if ($model =~ /^(0|1|2|3)$/){
				$arch = 'K5';
				$process = 'AMD 350nm';
				$year = '1996-97';}
			elsif ($model =~ /^(6)$/){
				$arch = 'K6';
				$process = 'AMD 350nm';
				$year = '1997-98';}
			elsif ($model =~ /^(7)$/){
				$arch = 'K6';
				$process = 'AMD 250nm';
				$year = '1997-98';}
			elsif ($model =~ /^(8)$/){
				$arch = 'K6-2';
				$process = 'AMD 250nm';
				$year = '1998-2003';}
			elsif ($model =~ /^(9)$/){
				$arch = 'K6-3';
				$process = 'AMD 250nm';
				$year = '1999-2003';}
			elsif ($model =~ /^(D)$/){
				$arch = 'K6-3';
				$process = 'AMD 180nm';
				$year = '1999-2003';}
			## unverified
			elsif ($model =~ /^(A)$/){
				$arch = 'K6 Geode';
				$process = 'AMD 150-350nm';
				$year = '1999';} # dates uncertain, 1999 start
			## fallback
			else {
				$arch = 'K6';
				$process = 'AMD 250-350nm';
				$year = '1999-2003';}
		}
		elsif ($family eq '6'){
			## verified
			if ($model =~ /^(1)$/){
				$arch = 'K7'; # 1:2:argon
				$process = 'AMD 250nm';
				$year = '1999-2001';}
			elsif ($model =~ /^(2|3|4|6)$/){
				# 3:0:duron;3:1:spitfire;4:2,4:thunderbird; 6:2:Palomino, duron; 2:1:Pluto
				$arch = 'K7'; 
				$process = 'AMD 180nm';
				$year = '2000-01';}
			elsif ($model =~ /^(7|8|A)$/){
				$arch = 'K7'; # 7:0,1:Morgan;8:1:thoroughbred,duron-applebred; A:0:barton
				$process = 'AMD 130nm';
				$year = '2002-04';}
			## fallback
			else {
				$arch = 'K7';
				$process = 'AMD 130-180nm';
				$year = '2003-14';}
		}
		# note: family F K8 needs granular breakdowns, was a long lived family
		elsif ($family eq 'F'){
			## verified 
			# check: B|E|F
			if ($model =~ /^(4|5|7|8|B|C|E|F)$/){
				# 4:0:clawhammer;5:8:sledgehammer;8:2,4:8:dubin;7:A;C:0:NewCastle;
				$arch = 'K8'; 
				$process = 'AMD 130nm';
				$year = '2004-05';}
			# check: 14|17|18|1B|25|48|4B|5D
			elsif ($model =~ /^(14|15|17|18|1B|1C|1F|21|23|24|25|27|28|2C|2F|37|3F|41|43|48|4B|4C|4F|5D|5F|C1)$/){
				# 1C:0,2C:2:Palermo;21:0,2,23:2:denmark;1F:0:winchester;2F:2:Venice;
				# 27:1,37:2:san diego;28:1,3F:2:Manchester;23:2:Toledo;$F:2,5F:2,3:Orleans;
				# 5F:2:Manila?;37:2;C1:3:windsor fx;43:2,3:santa ana;41:2:santa rosa;
				# 4C:2:Keene;2C:2:roma;24:2:newark
				$arch = 'K8'; 
				$process = 'AMD 90nm';
				$year = '2004-06';}
			elsif ($model =~ /^(68|6B|6C|6F|7C|7F)$/){
				$arch = 'K8'; # 7F:1,2:Lima; 68:1,6B:1,2:Brisbane;6F:2:conesus;7C:2:sherman
				$process = 'AMD 65nm';
				$year = '2005-08';}
			## fallback
			else {
				$arch = 'K8';
				$process = 'AMD 65-130nm';
				$year = '2004-2008';}
		}
		# K9 was planned but skipped
		elsif ($family eq '10'){ # 1F
			## verified
			if ($model =~ /^(2)$/){
				$arch = 'K10'; # 2:2:budapest;2:1,3:barcelona
				$process = 'AMD 65nm';
				$year = '2007-08';}
			elsif ($model =~ /^(4|5|6|8|9|A)$/){
				# 4:2:Suzuka;5:2,3:propus;6:2:Regor;8:0:Istanbul;9:1:maranello
				$arch = 'K10';  
				$process = 'AMD 45nm';
				$year = '2009-13';}
			## fallback
			else {
				$arch = 'K10';
				$process = 'AMD 45-65nm';
				$year = '2007-13';}
		}
		# very loose, all stepping 1: covers athlon x2, sempron, turion x2
		# years unclear, could be 2005 start, or 2008
		elsif ($family eq '11'){ # 2F
			if ($model =~ /^(3)$/){
				$arch = 'K11 Turion X2'; # mix of K8/K10
				$note = $check;
				$process = 'AMD 65-90nm';
				$year = ''; } 
		}
		# might also need cache handling like 14/16
		elsif ($family eq '12'){ # 3F
			if ($model =~ /^(1)$/){
				$arch = 'K12 Fusion'; # K10 based apu, llano
				$process = 'GF 32nm';
				$year = '2011';} # check years
			else {
				$arch = 'K12 Fusion';
				$process = 'GF 32nm';
				$year = '2011';} # check years
		}
		# SOC, apu
		elsif ($family eq '14'){ # 5F
			if ($model =~ /^(1|2)$/){
				$arch = 'Bobcat';
				$process = 'GF 40nm';
				$year = '2011-13';}
			else {
				$arch = 'Bobcat';
				$process = 'GF 40nm';
				$year = '2011-13';}
		}
		elsif ($family eq '15'){ # 6F
			# note: only model 1 confirmd
			if ($model =~ /^(0|1|3|4|5|6|7|8|9|A|B|C|D|E|F)$/){
				$arch = 'Bulldozer';
				$process = 'GF 32nm';
				$year = '2011';}
			# note: only 2,10,13 confirmed
			elsif ($model =~ /^(2|10|11|12|13|14|15|16|17|18|19|1A|1B|1C|1D|1E|1F)$/){
				$arch = 'Piledriver';
				$process = 'GF 32nm';
				$year = '2012-13';}
			# note: only 30,38 confirmed
			elsif ($model =~ /^(30|31|32|33|34|35|36|37|38|39|3A|3B|3C|3D|3E|3F)$/){
				$arch = 'Steamroller';
				$process = 'GF 28nm';
				$year = '2014';}
			# note; only 60,65,70 confirmed
			elsif ($model =~ /^(60|61|62|63|64|65|66|67|68|69|6A|6B|6C|6D|6E|6F|70|71|72|73|74|75|76|77|78|79|7A|7B|7C|7D|7E|7F)$/){
				$arch = 'Excavator';
				$process = 'GF 28nm';
				$year = '2015';}
			else {
				$arch = 'Bulldozer';
				$process = 'GF 32nm';
				$year = '2011-12';}
		}
		# SOC, apu
		elsif ($family eq '16'){ # 7F
			if ($model =~ /^(0|1|2|3|4|5|6|7|8|9|A|B|C|D|E|F)$/){
				$arch = 'Jaguar';
				$process = 'GF 28nm';
				$year = '2013-14';}
			elsif ($model =~ /^(30|31|32|33|34|35|36|37|38|39|3A|3B|3C|3D|3E|3F)$/){
				$arch = 'Puma';
				$process = 'GF 28nm';
				$year = '2014-15';}
			else {
				$arch = 'Jaguar';
				$process = 'GF 28nm';
				$year = '2013-14';}
		}
		elsif ($family eq '17'){ # 8F
			# can't find stepping/model for no ht 2x2 core/die models, only first ones
			if ($model =~ /^(1|11|20)$/){
				$arch = 'Zen';
				$process = 'GF 14nm';
				$year = '2017-19';}
			# Seen: stepping 1 is Zen+ Ryzen 7 3750H. But stepping 1 Zen is: Ryzen 3 3200U
			# AMD Ryzen 3 3200G is stepping 1, Zen+
			# Unknown if stepping 0 is Zen or either.
			elsif ($model =~ /^(18)$/){
				$arch = 'Zen/Zen+';
				$gen = '1';
				$process = 'GF 12nm';
				$note = $check;
				$year = '2019';}
			# shares model 8 with zen, stepping unknown
			elsif ($model =~ /^(8)$/){
				$arch = 'Zen+';
				$gen = '2';
				$process = 'GF 12nm';
				$year = '2018-21';}
			# used this but it didn't age well:  ^(2[0123456789ABCDEF]|
			elsif ($model =~ /^(3.|4.|5.|6.|7.|8.|9.|A.)$/){
				$arch = 'Zen 2';
				$gen = '3';
				$process = 'TSMC n7 (7nm)'; # some consumer maybe GF 14nm
				$year = '2020-22';}
			else {
				$arch = 'Zen';
				$note = $check;
				$process = '7-14nm';
				$year = '';}
		}
		# Joint venture between AMD and Chinese companies. Type amd? or hygon?
		elsif ($family eq '18'){ # 9F
			# model 0, zen 1 
			$arch = 'Zen (Hygon Dhyana)';
			$gen = '1';
			$process = 'GF 14nm';
			$year = '';}
		elsif ($family eq '19'){ # AF
			# zen 4 raphael, phoenix 1 use n5 I believe
			# Epyc Bergamo zen4c 4nm, only few full model IDs, update when appear
			# zen4c is for cloud hyperscale
			if ($model =~ /^(78)$/){
				$arch = 'Zen 4c';
				$gen = '5';
				$process = 'TSMC n4 (4nm)';
				$year = '2023+';}
			# ext model 6,7, base models trickling in
			# 10 engineering sample
			elsif ($model =~ /^(1.|6.|7.|A.)$/){
				$arch = 'Zen 4';
				$gen = '5';
				$process = 'TSMC n5 (5nm)';
				$year = '2022+';}
			# double check 40, 44; 21 confirmed
			elsif ($model =~ /^(21|4.)$/){
				$arch = 'Zen 3+';
				$gen = '4';
				$process = 'TSMC n6 (7nm)';
				$year = '2022';}
			# 21, 50: step 0; known: 21, 3x, 50
			elsif ($model =~ /^(0|1|8|2.|3.|5.)$/){
				$arch = 'Zen 3';
				$gen = '4';
				$process = 'TSMC n7 (7nm)';
				$year = '2021-22';}
			else {
				$arch = 'Zen 3/4';
				$note = $check;
				$process = 'TSMC n5 (5nm)';
				$year = '2021-22';}
		}
		# Zen 5: TSMC n3/n4, epyc turin / granite ridge? / turin dense zen 5c 3nm
		elsif ($family eq '20'){ # BF
			if ($model =~ /^(0)$/){
				$arch = 'Zen 5';
				$gen = '5';
				$process = 'TSMC n3 (3nm)'; # turin could be 4nm, need more data
				$year = '2023+';}
			# Strix Point; Granite Ridge; Krackan Point; Strix Halo
			elsif ($model =~ /^(10|20|40|60|70)$/){
				$arch = 'Zen 5';
				$gen = '5';
				$process = 'TSMC n3 (3nm)'; # desktop, granite ridge, confirm 2024
				$year = '2024+';}
			else {
				$arch = 'Zen 5';
				$note = $check;
				$process = 'TSMC n3/n4 (3,4nm)';
				$year = '2024+';}
		}
		# Roadmap: check to verify, AMD is usually closer to target than Intel
		# Epyc 4 genoa: zen 4, nm, 2022+ (dec 2022), cxl-1.1,pcie-5, ddr-5
	}
	# we have no advanced data for ARM cpus, this is an area that could be improved?
	elsif ($type eq 'arm'){
		if ($family ne ''){
			$arch="ARMv$family";}
		else {
			$arch='ARM';}
	}
	#	elsif ($type eq 'ppc'){
	#		$arch='PPC';
	#	}
	# aka VIA
	elsif ($type eq 'centaur'){ 
		if ($family eq '5'){
			if ($model =~ /^(4)$/){
				$arch = 'WinChip C6';
				$process = '250nm';
				$year = '';}
			elsif ($model =~ /^(8)$/){
				$arch = 'WinChip 2';
				$process = '250nm';
				$year = '';}
			elsif ($model =~ /^(9)$/){
				$arch = 'WinChip 3';
				$process = '250nm';
				$year = '';}
		}
		elsif ($family eq '6'){
			if ($model =~ /^(6)$/){
				$arch = 'Via Cyrix III (WinChip 5)';
				$process = '150nm'; # guess
				$year = '';}
			elsif ($model =~ /^(7|8)$/){
				$arch = 'Via C3';
				$process = '150nm';
				$year = '';}
			elsif ($model =~ /^(9)$/){
				$arch = 'Via C3-2';
				$process = '130nm';
				$year = '';}
			elsif ($model =~ /^(A|D)$/){
				$arch = 'Via C7';
				$process = '90nm';
				$year = '';}
			elsif ($model =~ /^(F)$/){
				if ($stepping <= 1){
					$arch = 'Via CN Nano (Isaah)';}
				elsif ($stepping <= 2){
					$arch = 'Via Nano (Isaah)';}
				elsif ($stepping <= 10){
					$arch = 'Via Nano (Isaah)';}
				elsif ($stepping <= 12){
					$arch = 'Via Isaah';}
				elsif ($stepping <= 13){
					$arch = 'Via Eden';}
				elsif ($stepping <= 14){
					$arch = 'Zhaoxin ZX';}
				$process = '90nm'; # guess
				$year = '';} 
		}
		elsif ($family eq '7'){
			if ($model =~ /^(1.|3.)$/){
				$arch = 'Zhaoxin ZX';
				$process = '90nm'; # guess
				$year = '';
			}
		}
	}
	# note, to test uncoment $cpu{'type'} = Elbrus in proc/cpuinfo logic
	# ExpLicit Basic Resources Utilization Scheduling
	elsif ($type eq 'elbrus'){ 
		# E8CB
		if ($family eq '4'){
			if ($model eq '1'){
				$arch = 'Elbrus 2000 (gen-1)';
				$process = 'Mikron 130nm';
				$year = '2005';}
			elsif ($model eq '2'){
				$arch = 'Elbrus-S (gen-2)';
				$process = 'Mikron 90nm';
				$year = '2010';}
			elsif ($model eq '3'){
				$arch = 'Elbrus-4C (gen-3)';
				$process = 'TSMC 65nm';
				$year = '2014';}
			elsif ($model eq '4'){
				$arch = 'Elbrus-2C+ (gen-2)';
				$process = 'Mikron 90nm';
				$year = '2011';}
			elsif ($model eq '6'){
				$arch = 'Elbrus-2CM (gen-2)';
				$note = $check;
				$process = 'Mikron 90nm';
				$year = '2011 (?)';}
			elsif ($model eq '7'){
				if ($stepping >= 2){
					$arch = 'Elbrus-8C1 (gen-4)';
					$process = 'TSMC 28nm';
					$year = '2016';}
				else {
					$arch = 'Elbrus-8C (gen-4)';
					$process = 'TSMC 28nm';
					$year = '2016';}
			} # note: stepping > 1 may be 8C1
			elsif ($model eq '8'){
				$arch = 'Elbrus-1C+ (gen-4)';
				$process = 'TSMC 40nm';
				$year = '2016';}
			# 8C2 morphed out of E8CV, but the two were the same die
			elsif ($model eq '9'){
				$arch = 'Elbrus-8CV/8C2 (gen-4/5)';
				$process = 'TSMC 28nm';
				$note = $check;
				$year = '2016/2020';}
			elsif ($model eq 'A'){
				$arch = 'Elbrus-12C (gen-6)';
				$process = 'TSMC 16nm';
				$year = '2021+';}
			elsif ($model eq 'B'){
				$arch = 'Elbrus-16C (gen-6)';
				$process = 'TSMC 16nm';
				$year = '2021+';}
			elsif ($model eq 'C'){
				$arch = 'Elbrus-2C3 (gen-6)';
				$process = 'TSMC 16nm';
				$year = '2021+';}
			else {
				$arch = 'Elbrus-??';;
				$note = $check;
				$year = '';}
		}
		elsif ($family eq '5'){
			if ($model eq '9'){
				$arch = 'Elbrus-8C2 (gen-4)';
				$process = 'TSMC 28nm';
				$year = '2020';}
			else {
				$arch = 'Elbrus-??';
				$note = $check;
				$process = '';
				$year = '';}
		}
		elsif ($family eq '6'){
			if ($model eq 'A'){
				$arch = 'Elbrus-12C (gen-6)';
				$process = 'TSMC 16nm'; 
				$year = '2021+';}
			elsif ($model eq 'B'){
				$arch = 'Elbrus-16C (gen-6)';
				$process = 'TSMC 16nm';
				$year = '2021+';}
			elsif ($model eq 'C'){
				$arch = 'Elbrus-2C3 (gen-6)';
				$process = 'TSMC 16nm';
				$year = '2021+';}
			# elsif ($model eq '??'){
			#	$arch = 'Elbrus-32C (gen-7)';
			#	$process = '?? 7nm';
			#	$year = '2025';}
			else {
				$arch = 'Elbrus-??';
				$note = $check;
				$process = '';
				$year = '';}
		}
		else {
			$arch = 'Elbrus-??';
			$note = $check;
		}
	}
	elsif ($type eq 'intel'){
		if ($family eq '4'){
			if ($model =~ /^(0|1|2)$/){
				$arch = 'i486';
				$process = '1000nm'; # 33mhz
				$year = '1989-98';}
			elsif ($model =~ /^(3)$/){
				$arch = 'i486';
				$process = '800nm'; # 66mhz
				$year = '1992-98';}
			elsif ($model =~ /^(4|5|6|7|8|9)$/){
				$arch = 'i486';
				$process = '600nm'; # 100mhz
				$year = '1993-98';}
			else {
				$arch = 'i486';
				$process = '600-1000nm';
				$year = '1989-98';}
		}
		# 1993-2000
		elsif ($family eq '5'){
			# verified
			if ($model =~ /^(1)$/){
				$arch = 'P5';
				$process = 'Intel 800nm'; # 1:3,5,7:800
				$year = '1993-94';}
			elsif ($model =~ /^(2)$/){
				$arch = 'P5'; # 2:5:MMX
				 # 2:C:350[or 600]; 2:1,4,5,6:600;but: 
				if ($stepping > 9){
					$process = 'Intel 350nm';
					$year = '1996-2000';}
				else {
					$process = 'Intel 600nm';
					$year = '1993-95';}
			}
			elsif ($model =~ /^(4)$/){
				$arch = 'P5';
				$process = 'Intel 350nm'; # MMX. 4:3:P55C
				$year = '1997';}
			# unverified
			elsif ($model =~ /^(3|7)$/){
				$arch = 'P5'; # 7:0:MMX
				$process = 'Intel 350-600nm';
				$year = '';}
			elsif ($model =~ /^(8)$/){
				$arch = 'P5';
				$process = 'Intel 350-600nm'; # MMX
				$year = '';}
			elsif ($model =~ /^(9|A)$/){
				$arch = 'Lakemont';
				$process = 'Intel 350nm';
				$year = '';}
			# fallback
			else {
				$arch = 'P5';
				$process = 'Intel 350-600nm'; # MMX
				$year = '1994-2000';}
		}
		elsif ($family eq '6'){
			if ($model =~ /^(1)$/){
				$arch = 'P6 Pro';
				$process = 'Intel 350nm';
				$year = '';}
			elsif ($model =~ /^(3)$/){
				$arch = 'P6 II Klamath';
				$process = 'Intel 350nm';
				$year = '';}
			elsif ($model =~ /^(5)$/){
				$arch = 'P6 II Deschutes';
				$process = 'Intel 250nm';
				$year = '';}
			elsif ($model =~ /^(6)$/){
				$arch = 'P6 II Mendocino';
				$process = 'Intel 250nm'; # 6:5:P6II-celeron-mendo
				$year = '1999';}
			elsif ($model =~ /^(7)$/){
				$arch = 'P6 III Katmai';
				$process = 'Intel 250nm';
				$year = '1999';}
			elsif ($model =~ /^(8)$/){
				$arch = 'P6 III Coppermine';
				$process = 'Intel 180nm';
				$year = '1999';}
			elsif ($model =~ /^(9)$/){
				$arch = 'M Banias'; # Pentium M
				$process = 'Intel 130nm';
				$year = '2003';}
			elsif ($model =~ /^(A)$/){
				$arch = 'P6 III Xeon';
				$process = 'Intel 180-250nm';
				$year = '1999';}
			elsif ($model =~ /^(B)$/){
				$arch = 'P6 III Tualitin'; # 6:B:1,4
				$process = 'Intel 130nm';
				$year = '2001';}
			elsif ($model =~ /^(D)$/){
				$arch = 'M Dothan'; # Pentium M
				$process = 'Intel 90nm';
				$year = '2003-05';}
			elsif ($model =~ /^(E)$/){
				$arch = 'M Yonah';
				$process = 'Intel 65nm';
				$year = '2006-08';}
			elsif ($model =~ /^(F|16)$/){
				$arch = 'Core2 Merom'; # 16:1:conroe-l[65nm]
				$process = 'Intel 65nm';
				$year = '2006-09';}
			elsif ($model =~ /^(15)$/){
				$arch = 'M Tolapai'; # pentium M system on chip
				$process = 'Intel 90nm';
				$year = '2008';} 
			elsif ($model =~ /^(17)$/){
				$arch = 'Penryn'; # 17:A:Core 2,Celeron-wolfdale,yorkfield
				$process = 'Intel 45nm';
				$year = '2008';}
			# had 25 also, but that's westmere, at least for stepping 2
			elsif ($model =~ /^(1A|1E|1F|2C|2E|2F)$/){
				$arch = 'Nehalem';
				$process = 'Intel 45nm';
				$year = '2008-10';}
			elsif ($model =~ /^(1C|26)$/){
				$arch = 'Bonnell';
				$process = 'Intel 45nm';
				$year = '2008-13';} # atom Bonnell? 27?
			elsif ($model =~ /^(1D)$/){
				$arch = 'Penryn';
				$process = 'Intel 45nm';
				$year = '2007-08';}
			# 25 may be nahelem in a stepping, check. Stepping 2 is westmere
			elsif ($model =~ /^(25|2C|2F)$/){
				$arch = 'Westmere'; # die shrink of nehalem
				$process = 'Intel 32nm';
				$year = '2010-11';}
			elsif ($model =~ /^(27|35|36)$/){
				$arch = 'Saltwell';
				$process = 'Intel 32nm';
				$year = '2011-13';}
			elsif ($model =~ /^(2A|2D)$/){
				$arch = 'Sandy Bridge';
				$process = 'Intel 32nm';
				$year = '2010-12';}
			elsif ($model =~ /^(37|4A|4D|5A|5D)$/){
				$arch = 'Silvermont';
				$process = 'Intel 22nm';
				$year = '2013-15';}
			elsif ($model =~ /^(3A|3E)$/){
				$arch = 'Ivy Bridge';
				$process = 'Intel 22nm';
				$year = '2012-15';}
			elsif ($model =~ /^(3C|3F|45|46)$/){
				$arch = 'Haswell';
				$process = 'Intel 22nm';
				$year = '2013-15';}
			elsif ($model =~ /^(3D|47|4F|56)$/){
				$arch = 'Broadwell';
				$process = 'Intel 14nm';
				$year = '2015-18';}
			elsif ($model =~ /^(4C)$/){
				$arch = 'Airmont';
				$process = 'Intel 14nm';
				$year = '2015-17';}
			elsif ($model =~ /^(4E)$/){
				$arch = 'Skylake';
				$process = 'Intel 14nm';
				$year = '2015';} 
			# need to find stepping for these, guessing stepping 4 is last for SL
			elsif ($model =~ /^(55)$/){
				if ($stepping >= 5 && $stepping <= 7){
					$arch = 'Cascade Lake';
					$process = 'Intel 14nm';
					$year = '2019';}
				elsif ($stepping >= 8){
					$arch = 'Cooper Lake'; # 55:A:14nm
					$process = 'Intel 14nm';
					$year = '2020';}
				else {
					$arch = 'Skylake';
					$process = 'Intel 14nm';
					$year = '';}}
			elsif ($model =~ /^(57)$/){
				$arch = 'Knights Landing';
				$process = 'Intel 14nm';
				$year = '2016+';}
			elsif ($model =~ /^(5C|5F)$/){
				$arch = 'Goldmont';
				$process = 'Intel 14nm';
				$year = '2016';}
			elsif ($model =~ /^(5E)$/){
				$arch = 'Skylake-S';
				$process = 'Intel 14nm';
				$year = '2015';}
			elsif ($model =~ /^(66|67)$/){
				$arch = 'Cannon Lake';
				$process = 'Intel 10nm';
				$year = '2018';}
			# 6 are servers, 7 not
			elsif ($model =~ /^(6A|6C|7D|7E|9F)$/){
				$arch = 'Ice Lake';
				$process = 'Intel 10nm';
				$year = '2019-21';}
			elsif ($model =~ /^(7A)$/){
				$arch = 'Goldmont Plus';
				$process = 'Intel 14nm';
				$year = '2017';} 
			elsif ($model =~ /^(85)$/){
				$arch = 'Knights Mill';
				$process = 'Intel 14nm';
				$year = '2017-19';}
			elsif ($model =~ /^(86)$/){
				$arch = 'Tremont Snow Ridge'; # embedded
				$process = 'Intel 10nm';
				$year = '2020';}
			elsif ($model =~ /^(87)$/){
				$arch = 'Tremont Parker Ridge'; # embedded
				$process = 'Intel 10nm';
				$year = '2022';}
			elsif ($model =~ /^(8A)$/){
				$arch = 'Tremont Lakefield';
				$process = 'Intel 10nm';
				$year = '2020';} # ?
			elsif ($model =~ /^(96)$/){
				$arch = 'Tremont Elkhart Lake';
				$process = 'Intel 10nm';
				$year = '2020';} # ?
			elsif ($model =~ /^(8C|8D)$/){
				$arch = 'Tiger Lake';
				$process = 'Intel 10nm';
				$year = '2020';}
			elsif ($model =~ /^(8E)$/){
				# can be AmberL or KabyL
				if ($stepping == 9){
					$arch = 'Amber/Kaby Lake';
					$note = $check;
					$process = 'Intel 14nm';
					$year = '2017';}
				elsif ($stepping == 10){
					$arch = 'Coffee Lake';
					$process = 'Intel 14nm';
					$year = '2017';}
				elsif ($stepping == 11){
					$arch = 'Whiskey Lake';
					$process = 'Intel 14nm';
					$year = '2018';}
				# can be WhiskeyL or CometL
				elsif ($stepping == 12){
					$arch = 'Comet/Whiskey Lake';
					$note = $check;
					$process = 'Intel 14nm';
					$year = '2018';}
				# note: had it as > 13, but 0xC seems to be CL
				elsif ($stepping >= 13){
					$arch = 'Comet Lake'; # 10 gen
					$process = 'Intel 14nm';
					$year = '2019-20';}
				# NOTE: not enough info to lock this down
				else {
					$arch = 'Kaby Lake';
					$note = $check;
					$process = 'Intel 14nm';
					$year = '~2018-20';} 
			}
			elsif ($model =~ /^(8F|95)$/){
				$arch = 'Sapphire Rapids';
				$process = 'Intel 7 (10nm ESF)';
				$year = '2023+';} # server
			elsif ($model =~ /^(97|9A|9C|BE)$/){
				$arch = 'Alder Lake'; # socket LG 1700
				$process = 'Intel 7 (10nm ESF)';
				$year = '2021+';}
			elsif ($model =~ /^(9E)$/){
				if ($stepping == 9){
					$arch = 'Kaby Lake';
					$process = 'Intel 14nm';
					$year = '2018';}
				elsif ($stepping >= 10 && $stepping <= 13){
					$arch = 'Coffee Lake'; # 9E:A,B,C,D
					$process = 'Intel 14nm';
					$year = '2018';}
				else {
					$arch = 'Kaby Lake';
					$note = $check;
					$process = 'Intel 14nm';
					$year = '2018';} 
			}
			elsif ($model =~ /^(A5|A6)$/){
				$arch = 'Comet Lake'; # 10 gen; stepping 0-5
				$process = 'Intel 14nm';
				$year = '2020';}
			elsif ($model =~ /^(A7|A8)$/){
				$arch = 'Rocket Lake'; # 11 gen; stepping 1
				$process = 'Intel 14nm';
				$year = '2021+';} 
			# More info: comet: shares family/model, need to find stepping numbers
			# Coming: meteor lake; granite rapids; emerald rapids, diamond rapids
			## IDS UNKNOWN, release late 2022
			elsif ($model =~ /^(AA|AB|AC|B5)$/){
				$arch = 'Meteor Lake'; # 14 gen
				$process = 'Intel 4 (7nm)';
				$year = '2023+';}
			elsif ($model =~ /^(AD|AE)$/){
				$arch = 'Granite Rapids'; # ?
				$process = 'Intel 3 (7nm+)'; # confirm
				$year = '2024+';}
			elsif ($model =~ /^(B6)$/){
				$arch = 'Grand Ridge'; # 14 gen
				$process = 'Intel 4 (7nm)'; # confirm
				$year = '2023+';}
			elsif ($model =~ /^(B7|BA|BF)$/){
				$arch = 'Raptor Lake'; # 13 gen, socket LG 1700,1800
				$process = 'Intel 7 (10nm)';
				$year = '2022+';}
			elsif ($model =~ /^(BC|BD)$/){
				$arch = 'Lunar Lake'; # 15 gn
				$process = 'Intel 18a (1.8nm)';
				$year = '2024+';} # seen APU IDs, so out there
			# Meteor Lake-S maybe cancelled, replaced by arrow
			elsif ($model =~ /^(C5|C6)$/){
				$arch = 'Arrow Lake'; # 15 gen; igpu battleimage 3/4nm
				# gfx tile is TSMC 3nm
				$process = 'Intel 20a (2nm)';# TSMC 3nm (corei3-5)/Intel 20A 2nm (core i5-9)
				$year = '2024+';} # check when actually in production
			elsif ($model =~ /^(CC)$/){
				$arch = 'Panther Lake';  # 17 gen
				$process = 'Intel 18a (1.8nm)';
				$year = '2025+';}
			elsif ($model =~ /^(CF)$/){
				$arch = 'Emerald Rapids'; # 5th gen xeon
				$process = 'Intel 7 (10nm)';
				$year = '2023+';}
			## roadmaps: check and update, since Intel misses their targets often
			# Sapphire Rapids: 13 gen (?), Intel 7 (10nm), 2023
			# Emerald Rapids: Intel 7 (10nm), 2023
			# Granite Rapids: Intel 3 (7nm+), 2024
			# Diamond Rapids: Intel 3 (7nm+), 2025
			# Raptor Lake: 13 gen, Intel 7 (10nm), 2022
			# Meteor Lake: 14 gen, Intel 4 (7nm+)
			# Arrow Lake:  15 gen, TSMC 3nm (corei3-5)/Intel 20A 2nm (core i5-9), 2024
			# Arrow Lake:  16 gen, TSMC 3nm (corei3-5)/Intel 20A 2nm (core i5-9), 2024, refresh
			# Lunar Lake:  15 gen, TSMC’s 3nm (N3B), 2024-5
			# Panther Lake:17 gen, ?, late 2025, cougar cove Xe3 Celestial GPU architecture
			# Beast Lake:  16 gen, ?, 2026?
			# Nova Lake:   18 gen, Intel 14A (1.4nm), 2026
		}
		# itanium 1 family 7 all recalled
		elsif ($family eq 'B'){
			if ($model =~ /^(0)$/){
				$arch = 'Knights Ferry';
				$process = 'Intel 45nm';
				$year = '2010-11';}
			if ($model =~ /^(1)$/){
				$arch = 'Knights Corner';
				$process = 'Intel 22nm';
				$year = '2012-13';}
		}
		# pentium 4
		elsif ($family eq 'F'){
			if ($model =~ /^(0|1)$/){
				$arch = 'Netburst Willamette';
				$process = 'Intel 180nm';
				$year = '2000-01';}
			elsif ($model =~ /^(2)$/){
				if ($stepping <= 4 || $stepping > 6){
					$arch = 'Netburst Northwood';}
				elsif ($stepping == 5){
					$arch = 'Netburst Gallatin';}
				else {
					$arch = 'Netburst';}
				$process = 'Intel 130nm';
				$year = '2002-03';}
			elsif ($model =~ /^(3)$/){
				$arch = 'Netburst Prescott';
				$process = 'Intel 90nm';
				$year = '2004-06';} # 6? Nocona
			elsif ($model =~ /^(4)$/){
				# these are vague, and same stepping can have > 1 core names
				if ($stepping < 10){
					$arch = 'Netburst Prescott'; # 4:1,9:prescott
					$process = 'Intel 90nm';
					$year = '2004-06';} 
				else {
					$arch = 'Netburst Smithfield';
					$process = 'Intel 90nm';
					$year = '2005-06';} # 6? Nocona
			}
			elsif ($model =~ /^(6)$/){
				$arch = 'Netburst Presler'; # 6:2,4,5:presler
				$process = 'Intel 65nm';
				$year = '2006';}
			else {
				$arch = 'Netburst';
				$process = 'Intel 90-180nm';
				$year = '2000-06';}
		}
		# this is not going to e accurate, WhiskyL or Kaby L can ID as Skylake
		# but if it's a new cpu microarch not handled yet, it may give better 
		# than nothing result. This is intel only
		# This is probably the gcc/clang -march/-mtune value, which is not 
		# necessarily the same as actual microarch, and varies between gcc/clang versions
		if (!$arch){
			my $file = '/sys/devices/cpu/caps/pmu_name';
			$arch = main::reader($file,'strip',0) if -r $file;
			$note = $check if $arch;
		}
		# gen 1 had no gen, only 3 digits: Core i5-661 Core i5-655K; Core i5 M 520
		# EXCEPT gen 1: Core i7-720QM Core i7-740QM Core i7-840QM
		# 2nd: Core i5-2390T Core i7-11700F Core i5-8400 
		# 2nd variants: Core i7-1165G7
		if ($name){
			if ($name =~ /\bi[357][\s-]([A-Z][\s-]?)?(\d{3}([^\d]|\b)|[78][24]00M)/){
				$gen = ($gen) ? "$gen (core 1)": 'core 1';
			}
			elsif ($name =~ /\bi[3579][\s-]([A-Z][\s-]?)?([2-9]|1[0-4])(\d{3}|\d{2}[A-Z]\d)/){
				$gen = ($gen) ? "$gen (core $2)" : "core $2";
			}
		}
	}
	eval $end if $b_log;
	return [$arch,$note,$process,$gen,$year];
}
## END CPU ARCH ##

# Only AMD/Intel 64 bit cpus
sub cp_cpu_level {
	eval $start if $b_log;
	my %flags = map {$_ =>1} split(/\s+/,$_[0]);
	my ($level,$note,@found);
	# note, each later cpu level must contain all subsequent cpu flags
	# baseline: all x86_64 cpus  lm cmov cx8 fpu fxsr mmx syscall sse2
	my @l1 = qw(cmov cx8 fpu fxsr lm mmx syscall sse2);
	my @l2 = qw(cx16 lahf_lm popcnt sse4_1 sse4_2 ssse3);
	my @l3 = qw(abm avx avx2 bmi1 bmi2 f16c fma movbe xsave);
	my @l4 = qw(avx512f avx512bw avx512cd avx512dq avx512vl);
	if ((@found = grep {$flags{$_}} @l1) && scalar(@found) == scalar(@l1)){
		$level = 'v1';
		# print 'v1: ', Data::Dumper::Dumper \@found;
		if ((@found = grep {$flags{$_}} @l2) && scalar(@found) == scalar(@l2)){
			$level = 'v2';
			# print 'v2: ', Data::Dumper::Dumper \@found;
			# It's not 100% certain that if flags exist v3/v4 supported. flags don't 
			# give full possible outcomes in these cases. See: docs/inxi-cpu.txt
			if ((@found = grep {$flags{$_}} @l3) && scalar(@found) == scalar(@l3)){
				$level = 'v3';
				# print 'v3: ', Data::Dumper::Dumper \@found;
				$note = main::message('note-check');
				if ((@found = grep {$flags{$_}} @l4) && scalar(@found) == scalar(@l4)){
					$level = 'v4';
					# print 'v4: ', Data::Dumper::Dumper \@found;
				}
			}
		}
	}
	$level = [$level,$note] if $level;
	eval $end if $b_log;
	return $level;
}

sub cp_cpu_topology {
	my ($counts,$topology) = @_;
	my @alpha = qw(Single Dual Triple Quad);
	my ($sep) = ('');
	my (%keys,%done);
	my @tests = ('x'); # prefill [0] because iterator runs before 'next' test.
	if ($counts->{'cpu-topo'}){
		# first we want to find out how many of each physical variant there are
		foreach my $topo (@{$counts->{'cpu-topo'}}){
			# turn sorted hash into string
			my $test = join('::', map{$_ . ':' . $topo->{$_}} sort keys %$topo);
			if ($keys{$test}){
				$keys{$test}++;
			}
			else {
				$keys{$test} = 1;
			}
			push(@tests,$test);
		}
		my ($i,$j) = (0,0);
		# then we build up the topology data per variant
		foreach my $topo (@{$counts->{'cpu-topo'}}){
			my $key = '';
			$i++;
			next if $done{$tests[$i]};
			$done{$tests[$i]} = 1;
			if ($b_admin && $type eq 'full'){
				$topology->{'full'}[$j]{'cpus'} = $keys{$tests[$i]};
				$topology->{'full'}[$j]{'cores'} = $topo->{'cores'};
				if ($topo->{'threads'} && $topo->{'cores'} != $topo->{'threads'}){
					$topology->{'full'}[$j]{'threads'} = $topo->{'threads'};
				}
				if ($topo->{'dies'} && $topo->{'dies'} > 1){
					$topology->{'full'}[$j]{'dies'} = $topo->{'dies'};
				}
				if ($counts->{'struct-mt'}){
					$topology->{'full'}[$j]{'cores-mt'} = $topo->{'cores-mt'};
				}
				if ($counts->{'struct-st'}){
					$topology->{'full'}[$j]{'cores-st'} = $topo->{'cores-st'};
				}
				if ($counts->{'struct-max'} || $counts->{'struct-min'}){
					$topology->{'full'}[$j]{'max'} = $topo->{'max'};
					$topology->{'full'}[$j]{'min'} = $topo->{'min'};
				}
				if ($topo->{'smt'}){
					$topology->{'full'}[$j]{'smt'} = $topo->{'smt'};
				}
				if ($topo->{'tpc'}){
					$topology->{'full'}[$j]{'tpc'} = $topo->{'tpc'};
				}
				$j++;
			}
			else {
				# start building string
				$topology->{'string'} .= $sep;
				$sep = ',';
				if ($counts->{'physical'} > 1) {
					my $phys = ($topology->{'struct-cores'}) ? $keys{$tests[$i]} : $counts->{'physical'};
					$topology->{'string'} .= $phys . 'x ';
					$topology->{'string'} .= $topo->{'cores'} . '-core';
				}
				else {
					$topology->{'string'} .= cp_cpu_alpha($topo->{'cores'});
				}
				# alder lake type cpu
				if ($topo->{'cores-st'} && $topo->{'cores-mt'}){
					$topology->{'string'} .= ' (' . $topo->{'cores-mt'} . '-mt/';
					$topology->{'string'} .= $topo->{'cores-st'} . '-st)';
				}
				# we only want to show > 1 phys short form basic if cpus have different 
				# core counts, not different min/max frequencies
				last if !$topology->{'struct-cores'};
			}
		}
	}
	else {
		if ($counts->{'physical'} > 1) {
			$topology->{'string'} = $counts->{'physical'} . 'x ';
			$topology->{'string'} .= $counts->{'cpu-cores'} . '-core';
		}
		else {
			$topology->{'string'} = cp_cpu_alpha($counts->{'cpu-cores'});
		}
	}
	$topology->{'string'} ||= '';
}

sub cp_cpu_alpha {
	my $cores = $_[0];
	my $string = '';
	if ($cores > 4){
		$string = $cores . '-core';
	}
	elsif ($cores == 0){
		$string = main::message('unknown-cpu-topology');
	}
	else {
		my @alpha = qw(single dual triple quad);
		$string = $alpha[$cores-1] . ' core';
	}
	return $string;
}

# Logic:
# if > 1 processor && processor id (physical id) == core id then Multi threaded (MT)
# if siblings > 1 && siblings ==  2 * num_of_cores ($cpu->{'cores'}) then Multi threaded (MT)
# if > 1 processor && processor id (physical id) != core id then Multi-Core Processors (MCP)
# if > 1 processor && processor ids (physical id) > 1 then Symmetric Multi Processing (SMP)
# if = 1 processor then single core/processor Uni-Processor (UP)
sub cp_cpu_type {
	eval $start if $b_log;
	my ($counts,$cpu,$tests) = @_;
	my $cpu_type = '';
	if ($counts->{'processors'} > 1 || 
	 (defined $tests->{'intel'} && $tests->{'intel'} && $cpu->{'siblings'} > 0)){
		# cpu_sys detected MT
		if ($counts->{'struct-mt'}){
			if ($counts->{'struct-mt'} && $counts->{'struct-st'}){
				$cpu_type .= 'MST'; 
			}
			else {
				$cpu_type .= 'MT'; 
			}
		}
		# handle case of OpenBSD that has hw.smt but no other meaningful topology
		elsif ($cpu->{'smt'}){
			$cpu_type .= 'MT' if $cpu->{'smt'} eq 'enabled'; 
		}
		# non-multicore MT, with 2 or more threads per core
		elsif ($counts->{'processors'} && $counts->{'physical'} && 
		 $counts->{'cpu-cores'} && 
		 $counts->{'processors'}/($counts->{'physical'} * $counts->{'cpu-cores'}) >= 2){
			# print "mt:1\n";
			$cpu_type .= 'MT'; 
		}
		# 2 or more siblings per cpu real core
		elsif ($cpu->{'siblings'} > 1 && $cpu->{'siblings'}/$counts->{'cpu-cores'} >= 2){
			# print "mt:3\n";
			$cpu_type .= 'MT'; 
		}
		# non-MT multi-core or MT multi-core
		if ($counts->{'cpu-cores'} > 1){
			if ($counts->{'struct-mt'} && $counts->{'struct-st'}){
				$cpu_type .= ' AMCP';
			}
			else {
				$cpu_type .= ' MCP';
			}
		}
		# only solidly known > 1 die cpus will use this
		if ($cpu->{'dies'} > 1){
			$cpu_type .= ' MCM'; 
		}
		# >1 cpu sockets active: Symetric Multi Processing
		if ($counts->{'physical'} > 1){
			if ($counts->{'struct-cores'} || $counts->{'struct-max'} || 
			 $counts->{'struct-min'}){
				$cpu_type .= ' AMP'; 
			}
			else {
				$cpu_type .= ' SMP'; 
			}
		}
		$cpu_type =~ s/^\s+//;
	}
	else {
		$cpu_type = 'UP';
	}
	eval $end if $b_log;
	return $cpu_type;
}

# Legacy: this data should be comfing from the /sys tool now.
# Was needed because no physical_id in cpuinfo, but > 1 cpu systems exist
# returns: 0: per cpu cores; 1: phys cpu count; 2: override model defaul names
sub cp_elbrus_data {
	eval $start if $b_log;
	my ($family_id,$model_id,$count,$arch) = @_;
	# 0: cores
	my $return = [0,1,$arch];
	my %cores = (
	# key=family id + model id
	'41' => 1,
	'42' => 1,
	'43' => 4,
	'44' => 2,
	'46' => 1,
	'47' => 8,
	'48' => 1,
	'49' => 8,
	'59' => 8,
	'4A' => 12,
	'4B' => 16,
	'4C' => 2,
	'6A' => 12,
	'6B' => 16,
	'6C' => 2,
	);
	$return->[0] = $cores{$family_id . $model_id} if $cores{$family_id . $model_id};
	if ($return->[0]){
		$return->[1] = ($count % $return->[0]) ? int($count/$return->[0]) + 1 : $count/$return->[0];
	}
	eval $end if $b_log;
	return $return;
}

sub cp_speed_data {
	eval $start if $b_log;
	my ($cpu,$cpu_sys) = @_;
	my $info = {};
	if (defined $cpu_sys->{'data'}){
		if (defined $cpu_sys->{'data'}{'speeds'}{'min-freq'}){
			$cpu->{'min-freq'} = $cpu_sys->{'data'}{'speeds'}{'min-freq'};
		}
		if (defined $cpu_sys->{'data'}{'speeds'}{'max-freq'}){
			$cpu->{'max-freq'} = $cpu_sys->{'data'}{'speeds'}{'max-freq'};
		}
		if (defined $cpu_sys->{'data'}{'speeds'}{'scaling-min-freq'}){
			$cpu->{'scaling-min-freq'} = $cpu_sys->{'data'}{'speeds'}{'scaling-min-freq'};
		}
		if (defined $cpu_sys->{'data'}{'speeds'}{'scaling-max-freq'}){
			$cpu->{'scaling-max-freq'} = $cpu_sys->{'data'}{'speeds'}{'scaling-max-freq'};
		}
		# we don't need to see these if they are the same
		if ($cpu->{'min-freq'} && $cpu->{'max-freq'} && 
		 $cpu->{'scaling-min-freq'} && $cpu->{'scaling-max-freq'} && 
		 $cpu->{'min-freq'} eq $cpu->{'scaling-min-freq'} &&
		 $cpu->{'max-freq'} eq $cpu->{'scaling-max-freq'}){
			undef $cpu->{'scaling-min-freq'};
			undef $cpu->{'scaling-max-freq'};
		}
		if (defined $cpu_sys->{'data'}{'speeds'}{'all'}){
			# only replace if we got actual speed values from cpufreq, or if no legacy
			# sourced processors data. Handles fake syz core speeds for counts.
			if ((grep {$_} @{$cpu_sys->{'data'}{'speeds'}{'all'}}) ||
			 !@{$cpu->{'processors'}}){
				$cpu->{'processors'} = $cpu_sys->{'data'}{'speeds'}{'all'};
			}
		}
		if (defined $cpu_sys->{'data'}{'cpufreq-boost'}){
			$cpu->{'boost'} = $cpu_sys->{'data'}{'cpufreq-boost'};
		}
	}
	if (defined $cpu->{'processors'}){
		if (scalar @{$cpu->{'processors'}} > 1){
			my ($agg,$high) = (0,0);
			for (@{$cpu->{'processors'}}){
				next if !$_; # bsds might have 0 or undef value, that's junk
				$agg += $_;
				$high = $_ if $_ > $high;
			}
			if ($agg){
				$cpu->{'avg-freq'} = int($agg/scalar @{$cpu->{'processors'}});
				$cpu->{'cur-freq'} = $high;
				$info->{'avg-speed-key'} = 'avg';
				$info->{'speed'} = $cpu->{'avg-freq'};
				if ($high > $cpu->{'avg-freq'}){
					$cpu->{'high-freq'} = $high;
					$info->{'high-speed-key'} = 'high';
				}
			}
		}
		elsif ($cpu->{'processors'}[0]) {
			$cpu->{'cur-freq'} = $cpu->{'processors'}[0];
			$info->{'speed'} = $cpu->{'cur-freq'};
		}
	}
	# BSDs generally will have processors count, but not per core speeds
	if ($cpu->{'cur-freq'} && !$info->{'speed'}){
		$info->{'speed'} = $cpu->{'cur-freq'};
	}
	if ($cpu->{'min-freq'} || $cpu->{'max-freq'}){
		($info->{'min-max'},$info->{'min-max-key'}) = cp_speed_min_max(
		$cpu->{'min-freq'},
		$cpu->{'max-freq'});
	}
	if ($cpu->{'scaling-min-freq'} || $cpu->{'scaling-max-freq'}){
		($info->{'scaling-min-max'},$info->{'scaling-min-max-key'}) = cp_speed_min_max(
		$cpu->{'scaling-min-freq'},
		$cpu->{'scaling-max-freq'},
		'sc');
	}
 	if ($cpu->{'cur-freq'}){
		if ($show{'short'}){
			$info->{'speed-key'} = 'speed';
		}
		elsif ($show{'cpu-basic'}){
			$info->{'speed-key'} = 'speed (MHz)';
		}
		else {
			$info->{'speed-key'} = 'Speed (MHz)';
		}
 	}
 	eval $end if $b_log;
 	return $info;
}

sub cp_speed_min_max {
	my ($min,$max,$type) = @_;
	my ($min_max,$key);
	if ($min && $max){
		$min_max = "$min/$max";
		$key = "min/max";
 	}
 	elsif ($max){
		$min_max = $max;
		$key = "max";
 	}
 	elsif ($min){
		$min_max = $min;
		$key = "min";
 	}
 	$key = $type . '-' . $key if $type && $key;
 	return ($min_max,$key);
}

# args: 0: cpu, by ref; 1: update $tests by reference
sub cp_test_types {
	my ($cpu,$tests) = @_;
	if ($cpu->{'type'} eq 'intel'){
		$$tests{'intel'} = 1;
		$$tests{'xeon'} = 1 if $cpu->{'model_name'} =~ /Xeon/i;
	}
	elsif ($cpu->{'type'} eq 'amd'){
		if ($cpu->{'family'} && $cpu->{'family'} eq '17'){
			$$tests{'amd-zen'} = 1;
			if ($cpu->{'model_name'}){
				if ($cpu->{'model_name'} =~ /Ryzen/i){ 
					$$tests{'ryzen'} = 1;
				}
				elsif ($cpu->{'model_name'} =~ /EPYC/i){
					$$tests{'epyc'} = 1;
				}
			}
		}
	}
	elsif ($cpu->{'type'} eq 'elbrus'){
		$$tests{'elbrus'} = 1;
	}
}

## CPU UTILITIES ##
# only elbrus ID is actually used live
sub cpu_vendor {
	eval $start if $b_log;
	my ($string) = @_;
	my ($vendor) = ('');
	$string = lc($string);
	if ($string =~ /intel/){
		$vendor = "intel";
	}
	elsif ($string =~ /amd/){
		$vendor = "amd";
	}
	# via/centaur/zhaoxin branding
	elsif ($string =~ /centaur|zhaoxin/){
		$vendor = "centaur";
	}
	elsif ($string eq 'elbrus'){
		$vendor = "elbrus";
	}
	eval $end if $b_log;
	return $vendor;
}

# do not define model-id, stepping, or revision, those can be 0 valid value
sub set_cpu_data {
	${$_[0]} = {
	'arch' => '',
	'avg-freq' => 0, # MHz
	'bogomips' => 0,
	'cores' => 0,
	'cur-freq' => 0, # MHz
	'dies' => 0,
	'family' => '',
	'flags' => '',
	'ids' => [],
	'l1-cache' => 0, # store in KB
	'l2-cache' => 0, # store in KB
	'l3-cache' => 0, # store in KB
	'max-freq' => 0, # MHz
	'min-freq' => 0, # MHz
	'model_name' => '',
	'processors' => [],
	'scalings' => [],
	'siblings' => 0,
	'type' => '',
	};
}

sub system_cpu_name {
	eval $start if $b_log;
	my ($compat,@working);
	my $cpus = {};
	if (@working = main::globber('/sys/firmware/devicetree/base/cpus/cpu@*/compatible')){
		foreach my $file (@working){
			$compat = main::reader($file,'',0);
			next if $compat =~ /timer/; # seen on android
			# these can have non printing ascii... why? As long as we only have the 
			# splits for: null 00/start header 01/start text 02/end text 03
			$compat = (split(/\x01|\x02|\x03|\x00/, $compat))[0] if $compat;
			$compat = (split(/,\s*/, $compat))[-1] if $compat;
			$cpus->{$compat} = ($cpus->{$compat}) ? ++$cpus->{$compat}: 1;
		}
	}
	# synthesize it, [4] will be like: cortex-a15-timer; sunxi-timer
	# so far all with this directory show soc name, not cpu name for timer
	elsif (! -d '/sys/firmware/devicetree/base' && $devices{'timer'}){
		foreach my $working (@{$devices{'timer'}}){
			next if $working->[0] ne 'timer' || !$working->[4] || $working->[4] =~ /timer-mem$/;
			$working->[4] =~ s/(-system)?-timer$//;
			$compat = $working->[4];
			$cpus->{$compat} = ($cpus->{$compat}) ? ++$cpus->{$compat}: 1;
		}
	}
	main::log_data('dump','%$cpus',$cpus) if $b_log;
	eval $end if $b_log;
	return $cpus;
}

## CLEANERS/OUTPUT HANDLERS ##
# MHZ - cell cpus
sub clean_speed {
	my ($speed,$opt) = @_;
	# eq '0' might be for string typing; value can be: <unknown>
	return if !$speed || $speed eq '0' || $speed =~ /^\D/;
	$speed =~ s/[GMK]HZ$//gi;
	$speed = ($speed/1000) if $opt && $opt eq 'khz';
	$speed = sprintf("%.0f", $speed);
	return $speed;
}

sub clean_cpu {
	my ($cpu) = @_;
	return if !$cpu;
	my $filters = '@|cpu |cpu deca|([0-9]+|single|dual|two|triple|three|tri|quad|four|';
	$filters .= 'penta|five|hepta|six|hexa|seven|octa|eight|multi)[ -]core|';
	$filters .= 'ennea|genuine|multi|processor|single|triple|[0-9\.]+ *[MmGg][Hh][Zz]';
	$cpu =~ s/$filters//ig;
	$cpu =~ s/\s\s+/ /g;
	$cpu =~ s/^\s+|\s+$//g;
	return $cpu;
}

sub hex_and_decimal {
	my ($data) = @_; 
	$data = '' if !defined $data;
	if ($data =~ /\S/){
		# only handle if a short hex number!! No need to prepend 0x to 0-9
		if ($data =~ /^[0-9a-f]{1,3}$/i && hex($data) ne $data){
			$data .= ' (' . hex($data) . ')';
			$data = '0x' . $data;
		}
	}
	else {
		$data = 'N/A';
	}
	return $data;
}
}
