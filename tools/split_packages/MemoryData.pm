package MemoryData;

sub get {
	eval $start if $b_log;
	my ($type) = @_;
	$loaded{'memory'} = 1;
	my ($memory);
	# netbsd 8.0 uses meminfo, but it uses it in a weird way
	if (!$force{'vmstat'} && (!$bsd_type || ($force{'meminfo'} && $bsd_type)) && 
	(my $file = $system_files{'proc-meminfo'})){
		$memory = linux_data($type,$file);
	}
	else {
		$memory = bsd_data($type);
	}
	eval $end if $b_log;
	return $memory;
}

# $memory:
# 0: available (not reserved or iGPU)
# 1: used (of available)
# 2: used %
# 3: gpu (raspberry pi only)
# Linux only, but could be extended if anyone wants to do the work for BSDs
# 4: array ref: sys_memory [total, blocks, block-size, count factor]
# 5: array ref: proc/iomem [total, reserved, gpu]
#
# args: 0: source, the caller; 1: $row hash ref; 2: $num ref; 3: indent
sub row {
	eval $start if $b_log;
	my ($source,$row,$num,$indent) = @_;
	$loaded{'memory'} = 1;
	my ($available,$gpu_ram,$note,$total,$used);
	my $memory = get('full');
	if ($memory){
		# print Data::Dumper::Dumper $memory;
		if ($memory->[3]){
			$gpu_ram = $memory->[3];
		}
		elsif ($memory->[5] && $memory->[5][2]){
			$gpu_ram = $memory->[5][2];
		}
		# Great, we have the real RAM data.
		if ($show{'ram'} && ($total = RamItem::ram_total())){
			$total = main::get_size($total,'string');
		}
		elsif ($memory->[4] || $memory->[5]){
			process_total($memory,\$total,\$note);
		}
		if ($gpu_ram){
			$gpu_ram = main::get_size($gpu_ram,'string');
		}
		$available = main::get_size($memory->[0],'string') if $memory->[0];
		$used = main::get_size($memory->[1],'string') if $memory->[1];
		$used .= " ($memory->[2]%)" if $memory->[2];
	}
	my $field = ($source eq 'info') ? 'Memory' : 'System RAM';
	$available ||= 'N/A';
	$total ||= 'N/A';
	$used ||= 'N/A';
	$row->{main::key($$num++,1,$indent,$field)} = '';
	$row->{main::key($$num++,1,$indent+1,'total')} = $total;
	$row->{main::key($$num++,0,$indent+2,'note')} = $note if $note;
	$row->{main::key($$num++,0,$indent+1,'available')} = $available;
	$row->{main::key($$num++,0,$indent+1,'used')} = $used;
	$row->{main::key($$num++,0,$indent+1,'igpu')} = $gpu_ram if $gpu_ram;
	eval $end if $b_log;
}

## LINUX DATA ##
sub linux_data {
	eval $start if $b_log;
	my ($type,$file) = @_;
	my ($available,$buffers,$cached,$free,$gpu,$not_used,$total_avail) = (0,0,0,0,0,0,0);
	my ($iomem,$memory,$sys_memory,$total);
	my @data = main::reader($file);
	# Note: units kB should mean 1000x8 bits, but actually means KiB! Confusing
	foreach (@data){
		# Not actual total, it's total physical minus reserved/kernel/system.
		if ($_ =~ /^MemTotal:/){
			$total_avail = main::get_piece($_,2);
		}
		elsif ($_ =~ /^MemFree:/){
			$free = main::get_piece($_,2); 
		}
		elsif ($_ =~ /^Buffers:/){
			$buffers = main::get_piece($_,2); 
		}
		elsif ($_ =~ /^Cached:/){
			$cached = main::get_piece($_,2); 
		}
		elsif ($_ =~ /^MemAvailable:/){
			$available = main::get_piece($_,2);
		}
	}
	$gpu = gpu_ram_arm() if $risc{'arm'};
	if ($type ne 'short' && ($fake{'sys-mem'} || -d '/sys/devices/system/memory')){
		sys_memory(\$sys_memory);
	}
	if ($type ne 'short' && ($fake{'iomem'} || ($b_root && -r '/proc/iomem'))){
		proc_iomem(\$iomem);
	}
	# $gpu = main::translate_size('128M');
	# $total_avail += $gpu; # not using because this ram is not available to system
	if ($available){
		$not_used = $available;
	}
	# Seen fringe cases, where total - free+buff+cach < 0
	# The idea is that the OS must be using 10MiB of ram or more
	elsif (($total_avail - ($free + $buffers + $cached)) > 10000){
		$not_used = ($free + $buffers + $cached);
	}
	# Netbsd goes < 0, but it's wrong, so dump the cache
	elsif (($total_avail - ($free + $buffers)) > 10000){
		$not_used = ($free + $buffers);
	}
	else {
		$not_used = $free;
	}
	my $used = ($total_avail - $not_used);
	my $percent = ($used && $total_avail) ? sprintf("%.1f", ($used/$total_avail)*100) : '';
	if ($type eq 'short'){
		$memory = short_data($total_avail,$used,$percent);
	}
	else {
		# raw return in KiB
		$memory = [$total_avail,$used,$percent,$gpu,$sys_memory,$iomem];
	}
	# print "$total_avail, $used, $percent, $gpu\n";
	# print Data::Dumper::Dumper $memory;
	main::log_data('data',"memory ref: $memory") if $b_log;
	eval $end if $b_log;
	return $memory;
}

# All values 0 if not root, but it is readable.
# See inxi-perl/dev/code-snippets.pl for original attempt, with pci/reserved
# args: 0: $iomem by ref
sub proc_iomem {
	eval $start if $b_log;
	my $file = '/proc/iomem';
	my ($buffer,$gpu,$pci,$reserved,$rom,$system) = (0,0,0,0,0,0);
	my $b_reserved;
	no warnings 'portable';
	if ($fake{'iomem'}){
		# $file = "$fake_data_dir/memory/proc-iomem-128gb-1.txt";
		# $file = "$fake_data_dira/memory/proc-iomem-544mb-igpu.txt";
		# $file = "$fake_data_dir/memory/proc-iomem-64mb-vram-stolen.txt";
		# $file = "$fake_data_dir/memory/proc-iomem-rh-1-matrox.txt";
		# $file = "$fake_data_dir/memory/proc-iomem-2-vram.txt";
		# $file = "$fake_data_dir/memory/proc-iomem-512mb-1.txt";
		# $file = "$fake_data_dir/memory/proc-iomem-518mb-reserved-1.txt";
		# $file = "$fake_data_dir/memory/proc-iomem-512mb-2-onboardgpu-active.txt";
		# $file = "$fake_data_dir/memory/proc-iomem-512mb-system-1.txt";
		# $file = "$fake_data_dir/memory/proc-iomem-257.18gb-system-1.txt";
		# $file = "$fake_data_dir/memory/proc-iomem-192gb-system-1.txt";
		 $file = "$fake_data_dir/memory/proc-iomem-1012mb-igpu.txt";
	}
	foreach ((main::reader($file),'EOF')){
		if ($dbg[54]){
			if (/^\s*([0-9a-f]+)-([^\s]+) : /){
				print $_,"\n",'        size: ';
				print main::get_size(((hex($2) - hex($1) + 1)/1024),'string'), "\n";
			}
		}
		# Get everythign solidly System RAM
		if (/^([0-9a-f]+)-([^\s]+) : (System RAM)$/i){
			$system += hex($2) - hex($1) + 1;
		}
		elsif (/^([0-9a-f]+)-([^\s]+) : (Ram buffer)$/i){
			$buffer += hex($2) - hex($1) + 1;
		}
		# Sometimes primary Reserved block contains PCI and other non RAM devices,
		# but also can contain non RAM addresses, maybe NVMe?
		elsif (/^([0-9a-f]+)-([^\s]+) : (Reserved)$/i){
			$reserved += hex($2) - hex($1) + 1;
		}
		# Legacy System ROM not in a Reserved block, primary item.
		elsif (/^\s*([0-9a-f]+)-([^\s]+) : (System ROM)$/i){
			$rom += hex($2) - hex($1) + 1;
		}
		elsif (/^([0-9a-f]+)-([^\s]+) : (ACPI Tables)$/i){
			$rom += hex($2) - hex($1) + 1;
		}
		# Incomplete because sometimes Reserved blocks contain PCI etc devices
		elsif (/^([0-9a-f]+)-([^\s]+) : (PCI .*)$/){
			$pci += hex($2) - hex($1) + 1;
		}
		# Graphics stolen memory/Video RAM area, but legacy had inside PCI blocks,
		# not reserved, or as primary. That behavior seems to have changed.
		if (/^\s*([0-9a-f]+)-([^\s]+) : (?:(Video RAM|Graphics).*)$/i){
			$gpu += hex($2) - hex($1) + 1;
		}
	}
	if ($dbg[54] || $b_log){
		my $d = ['iomem:','System: ' . main::get_size(($system/1024),'string'),
		'Reserved: ' . main::get_size(($reserved/1024),'string'), 
		'Buffer: ' . main::get_size(($buffer/1024),'string'),
		'iGPU: ' . main::get_size(($gpu/1024),'string'),
		'ROM: ' . main::get_size(($rom/1024),'string'),
		'System+iGPU+buffer+rom: ' . main::get_size((($system+$gpu+$buffer+$rom)/1024),'string'), 
		'  Raw GiB: ' . ($system+$gpu+$buffer+$rom)/1024**3, 
		'System+reserved: ' . main::get_size((($system+$reserved)/1024),'string'), 
		'  Raw GiB: ' . ($system+$reserved)/1024**3,
		'System+reserved+buffer: ' . main::get_size((($system+$reserved+$buffer)/1024),'string'), 
		'  Raw GiB: ' . ($system+$reserved+$buffer)/1024**3,
		'Reserved-iGPU: ' . main::get_size((($reserved-$gpu)/1024),'string'),
		'PCI Bus: ' . main::get_size(($pci/1024),'string')];
		main::log_data('dump','$d iomem',$d) if $b_log;
		print "\n",join("\n",@$d),"\n\n" if $dbg[54];
	}
	if ($gpu || $system || $reserved){
		# This combination seems to provide the bwest overall result
		$system += $gpu + $rom + $buffer;
		${$_[0]} = [$system/1024,$reserved/1024,$gpu/1024];
	}
	main::log_data('dump','$iomem',$_[0]) if $b_log;
	print 'proc/iomem: ', Data::Dumper::Dumper $_[0] if $dbg[53];
	eval $end if $b_log;
}

# Note: seen case where actual 128 GiB, result here 130, 65x2GiB. Also cases
# where blocks under expected total, this may be related to active onboard gpu.
sub sys_memory {
	eval $start if $b_log;
	return if !$fake{'sys-mem'} && ! -r '/sys/devices/system/memory/block_size_bytes';
	my ($count,$factor,$size,$total) = (0,1,0,0);
	# state = off,online; online = 1/0
	foreach my $online (main::globber('/sys/devices/system/memory/memory*/online')){
		$count++ if main::reader($online,'',0); # content 1/0, so will read as t/f
	}
	if ($count){
		$size = main::reader('/sys/devices/system/memory/block_size_bytes','',0);
		if ($size){
			$size = hex($size)/1024; # back to integer KiB
			$total = $count * $size;
		}
	}
	if ($fake{'sys-mem'}){
		# ($total,$count,$size) = (,,); # 
		# ($total,$count,$size) = (4194304,32,131072); # 4gb
		# ($total,$count,$size) = (7864320,60,131072); # 7.5 gb, -4 blocks
		# ($total,$count,$size) = (136314880,65,2097152); # 130 gb, +1 block
		# ($total,$count,$size) = (8126464,62,131072); # 7.75 gb, -2 blocks, vram?
		# ($total,$count,$size) = (33554432,256,131072); # 32 gb
		# ($total,$count,$size) = (8388608,64,131072); # 8gb
		# ($total,$count,$size) = (270532608,129,2097152); # 258 gb, +1 block
		# ($total,$count,$size) = (17563648,134,131072); # 16.75 gb, +6 block
		# ($total,$count,$size) = (3801088,29,131072); # 3.62 gb, -3 blocks 
		# ($total,$count,$size) = (67108864,32,2097152); # 64 gb
		# ($total,$count,$size) = (524288,4,131072); # 512 mb, maybe -4 blocks, vm
	}
	# Max stick size assumed: 64 blocks: 8 GiB/128 GiB min module: 2 GiB/32 GiB
	# 128 blocks: 16 GiB/256 GiB min module: 4 GiB/64 GiB but no way to know
	# Note: 128 MiB blocks; > 32 GiB, 2 GiB blocks, I think.
	# 64: 8 GiB/256 GiB, min module: 2 GiB/32 GiB
	if ($count > 32){ 
		$factor = 16;}
	# 32: 4 GiB/64 GiB, min module: 1 GiB/16 GiB
	elsif ($count > 16){
		$factor = 8;}
	# 16: 2 GiB, min module: 512 MiB
	elsif ($count > 8){
		$factor = 4;}
	# 8: 1 GiB, min module: 256 MiB
	elsif ($count > 4){
		$factor = 2;}
	# 4: 512 MiB, min module: 128 MiB
	else {
		$factor = 1;}
	if ($total || $count || $size){
		${$_[0]} = [$total,$count,$size,$factor];
	}
	if ($dbg[54] || $b_log){
		my $d = ['/sys:','Total: ' . main::get_size($total,'string'),
		'Blocks: ' . $count, 
		'Block-size: ' . main::get_size($size,'string'),
		"Count-factor: $count % $factor: " . $count % $factor];
		main::log_data('dump','$d sys-mem',$d) if $b_log;
		print "\n",join("\n",@$d),"\n\n" if $dbg[54];
	}
	main::log_data('dump','$sys_memory',$_[0]) if $b_log;
	print 'sys memory: ', Data::Dumper::Dumper $_[0] if $dbg[53];
	eval $end if $b_log;
}

# These are hacks since the phy ram real data is not available in clear form
# args: 0: memory array ref; 1: $total ref; 2: $note ref.
sub process_total {
	eval $start if $b_log;
	my ($memory,$total,$note) = @_;
	my ($d,$b_vm,@info);
	my $src = '';
	$b_vm = MachineItem::is_vm() if $show{'machine'};
	# Seen case where actual 128 GiB, result here 130, 65x2GiB. Maybe nvme?
	# This can be over or under phys ram
	if ($memory->[4] && $memory->[4][0]){
		@info = main::get_size($memory->[4][0]);
		# We want to show note for probably wrong results
		if ((!$fake{'sys-mem'} && $memory->[0] && $memory->[4][0] < $memory->[0]) || 
		(!$b_vm && $memory->[4][1] % $memory->[4][3] != 0)){
			$$note = main::message('note-check');
		}
		$src = 'sys';
	}
	# Note: this is a touch under the real ram amount, varies, igpu/vram can eat it.
	# This working total will only be under phys ram.
	if ($memory->[5] && $memory->[5][0] && 
	(!$memory->[4] || !$memory->[4][0] || ($memory->[4][0] != $memory->[5][0]))){
		@info = main::get_size($memory->[5][0]);
		$src = 'iomem';
	}
	if (@info){
		$$note = '';
		if (!$b_vm){
			# $info[0] = 384;
			# $info[1] = 'MiB';
			my ($factor,$factor2) = (1,0.5);
			# For M, assume smallest is 128, anything older won't even work probably.
			# For T RAM, the system ram is going to be 99.9% of physical because the 
			# reserved stuff is going to be tiny, I believe. We will see.
			# T array stick sizes: 128/256/512/1024 G
			# Note: samsung ships 1T modules (2024?), 512G (2023).
			if ($info[0] > 512){
				$factor = ($info[1] eq 'MiB') ? 256 : 64;
			}
			elsif ($info[0] > 256){
				$factor =  ($info[1] eq 'MiB') ? 128 : 32;
			}
			elsif ($info[0] > 128){
				$factor = ($info[1] eq 'MiB') ? 64 : 16;
			}
			elsif ($info[0] > 64){
				$factor = 8;
			}
			elsif ($info[0] > 16){
				$factor = 4;
			}
			elsif ($info[0] > 8){
				$factor = 4;
			}
			elsif ($info[0] > 4){
				$factor = 2;
			}
			elsif ($info[0] > 3){
				$factor = 1;
			}
			elsif ($info[0] > 2){
				$factor = ($info[1] eq 'TiB') ? 0.25 : 0.5;
			}
			# Note: get_size returns 1 as 1024, so we never actually see 1
			elsif ($info[0] > 1){
				$factor = ($info[1] eq 'TiB') ? 0.125 : 0.25;
			}
			my $result = $info[0] / $factor;
			my $mod = ((100 * $result) % 100);
			if ($b_log || $dbg[54]){
				push(@$d,"src: $src result: $info[0] / $factor: $result math-modulus: $mod");
			}
			if ($mod > 0){
				my ($check,$working) = (0,0);
				# Sometimes Perl generates a tiny value over 0.1: 0.100000000000023
				# but also we want to be a little loose here. Note that when high 
				# numbers, like 1012 M, we want the math much looser.
				# Within ~ 5% 
				if ($info[1] eq 'MiB'){
					if ($info[0] > 768){
						$check = 64;
					}
					elsif ($info[0] > 512){
						$check = 32;
					}
					elsif ($info[0] > 256){
						$check = 16;
					}
					else {
						$check = 4;
					}
				}
				# Within ~ 1%
				elsif ($info[1] eq 'GiB'){
					if ($info[0] > 512){
						$check = 4;
					}
					elsif ($info[0] > 256){
						$check = 2;
					}
					elsif ($info[0] > 3){
						$check = 0.25;
					}
					else {
						$check = 0.1;
					}
				}
				# Will need to verify this T assumption on real data one day, but keep 
				# in mind how much reserved ram this would be!
				elsif ($info[1] eq 'TiB'){
					if ($info[0] > 16){
						$check = 0.25;
					}
					elsif ($info[0] > 8){
						$check = 0.15;
					}
					elsif ($info[0] > 2){
						$check = 0.1;
					}
					else {
						$check = 0.05;
					}
				}
				# iomem is always under, sys can be over or under. we want fractional
				# corresponding value over or under result.
				# sys has block sizes: 128M, 2G, 32G, so sizes will always be divisible
				if ($src eq 'sys'){
					if ($info[0] > 64){
						$factor2 = 0.25;
					}
				}
				if ($src eq 'sys' && int($result + $factor2) == int($result)){
					$working = int($result) * $factor;
				}
				else {
					$working = POSIX::ceil($result) * $factor;
				}
				if ($b_log || $dbg[54]){
					push(@$d, "factor2: $factor2 floor_res+fact2: " . int($result + $factor2),
					"ceil_result * factor: " . (POSIX::ceil($result) * $factor),
					"floor_result * factor: " . (int($result) * $factor));
				}
				if (abs(($working - $info[0])) < $check){
					if ($src eq 'sys' && $info[0] != $working){
						$$note = main::message('note-est');
					}
					if ($b_log || $dbg[54]){
						push(@$d,"check less: ($working - $info[0]) < $check: ",
						"result: inside ceil < $check, clean");
					}
				}
				else {
					if ($b_log || $dbg[54]){
						push(@$d,"check not less: ($working - $info[0]) < $check: ",
						"set: $info[0] = $working");
					}
					$$note = main::message('note-est');
				}
				$info[0] = $working;
			}
			else {
				if ($b_log || $dbg[54]){
					push(@$d,"result: clean match, no change: $info[0] $info[1]");
				}
			}
		}
		else {
			my $dec = ($info[1] eq 'MiB') ? 1: 2;
			$info[0] = sprintf("%0.${dec}f",$info[0]) + 0;
			if ($b_log || $dbg[54]){
				push(@$d,"result: vm, using size: $info[0] $info[1]");
			}
		}
		$$total = $info[0] . ' ' . $info[1];
	}
	if ($b_log || $dbg[54]){
		main::log_data('dump','debugger',$d) if $b_log;
		print Data::Dumper::Dumper $d if $dbg[54];
	}
	eval $end if $b_log;
}

## BSD DATA ##
## openbsd/linux
# procs    memory       page                    disks    traps          cpu
# r b w    avm     fre  flt  re  pi  po  fr  sr wd0 wd1  int   sys   cs us sy id
# 0 0 0  55256 1484092  171   0   0   0   0   0   2   0   12   460   39  3  1 96
## openbsd 6.3? added in M/G/T etc, sigh...
# 2 57 55M 590M 789 0 0 0...
## freebsd:
# procs      memory      page                    disks     faults         cpu
# r b w     avm    fre   flt  re  pi  po    fr  sr ad0 ad1   in   sy   cs us sy id
# 0 0 0  21880M  6444M   924  32  11   0   822 827   0   0  853  832  463  8  3 88
# with -H
# 2 0 0 14925812  936448    36  13  10   0    84  35   0   0   84   30   42 11  3 86
## dragonfly: V1, supported -H
#  procs      memory      page                    disks     faults      cpu
#  r b w     avm    fre  flt  re  pi  po  fr  sr ad0 ad1   in   sy  cs us sy id
#  0 0 0       0  84060 30273993 2845 12742 1164 407498171 320960902   0   0 ....
## dragonfly: V2, no avm, no -H support
sub bsd_data {
	eval $start if $b_log;
	my ($type) = @_;
	my ($avm,$av_pages,$cnt,$fre,$free_mem,$mult,$real_mem,$total) = (0,0,0,0,0,0,0,0);
	my (@data,$memory,$message);
	# my $arg = ($bsd_type ne 'openbsd' && $bsd_type ne 'dragonfly') ? '-H' : '';
	if (my $program = main::check_program('vmstat')){
		# See above, it's the last line. -H makes it hopefully all in kB so no need 
		# for K/M/G tests, note that -H not consistently supported, so don't use.
		my @vmstat = main::grabber("vmstat 2>/dev/null",'\n','strip');
		main::log_data('dump','@vmstat',\@vmstat) if $b_log;
		my @header = split(/\s+/, $vmstat[1]);
		foreach (@header){
			if ($_ eq 'avm'){$avm = $cnt}
			elsif ($_ eq 'fre'){$fre = $cnt}
			elsif ($_ eq 'flt'){last;}
			$cnt++;
		}
		my $row = $vmstat[-1];
		if ($row){
			@data = split(/\s+/, $row);
			# Openbsd 6.3, dragonfly 5.x introduced an M / G character, sigh.
			if ($avm > 0 && $data[$avm] && $data[$avm] =~ /^([0-9\.]+[KGMT])(iB|B)?$/){
				$data[$avm] = main::translate_size($1);
			}
			if ($fre > 0 && $data[$fre] && $data[$fre] =~ /^([0-9\.]+[KGMT])(iB|B)?$/){
				$data[$fre] = main::translate_size($1);
			}
			# Dragonfly can have 0 avg, or no avm, sigh, but they may fix that so make test dynamic
			if ($avm > 0 && $data[$avm] != 0){
				$av_pages = ($bsd_type !~ /^(net|open)bsd$/) ? sprintf('%.1f',$data[$avm]/1024) : $data[$avm];
			}
			if ($fre > 0 && $data[$fre] != 0){
				$free_mem = sprintf('%.1f',$data[$fre]);
			}
		}
	}
	# Code to get total goes here:
	if ($alerts{'sysctl'}->{'action'} eq 'use'){
		# For dragonfly, we will use free mem, not used because free is 0
		my @working;
		if ($sysctl{'memory'}){
			foreach (@{$sysctl{'memory'}}){
				# Freebsd seems to use bytes here
				if (!$real_mem && /^hw.physmem:/){
					@working = split(/:\s*/, $_);
					# if ($working[1]){
						$working[1] =~ s/^[^0-9]+|[^0-9]+$//g;
						$real_mem = sprintf("%.1f", $working[1]/1024);
					# }
					last if $free_mem;
				}
				# But, it uses K here. Openbsd/Dragonfly do not seem to have this item
				# This can be either: Free Memory OR Free Memory Pages
				elsif (/^Free Memory:/){
					@working = split(/:\s*/, $_);
					$working[1] =~ s/[^0-9]+//g;
					$free_mem = sprintf("%.1f", $working[1]);
					last if $real_mem;
				}
			}
		}
	}
	else {
		$message = "sysctl $alerts{'sysctl'}->{'action'}"
	}
	# Not using, but leave in place for a bit in case we want it
	# my $type = ($free_mem) ? ' free':'' ;
	# Hack: temp fix for openbsd/darwin: in case no free mem was detected but we have physmem
	if (($av_pages || $free_mem) && !$real_mem){
		my $error = ($message) ? $message: 'total N/A';
		my $used = (!$free_mem) ? $av_pages : $real_mem - $free_mem;
		if ($type eq 'short'){
			$memory = short_data($error,$used);
		}
		else {
			$memory = [$error,$used,undef];
		}
	}
	# Use openbsd/dragonfly avail mem data if available
	elsif (($av_pages || $free_mem) && $real_mem){
		my $used = (!$free_mem) ? $av_pages : $real_mem - $free_mem;
		my $percent = ($used && $real_mem) ? sprintf("%.1f", ($used/$real_mem)*100) : '';
		if ($type eq 'short'){
			$memory = short_data($real_mem,$used,$percent);
		}
		else {
			$memory = [$real_mem,$used,$percent,0];
		}
	}
	eval $end if $b_log;
	return $memory;
}

## TOOLS ##
# args: 0: avail memory; 1: used memory; 2: percent used
sub short_data {
	# some BSDs, no available
	my @avail = (main::is_numeric($_[0])) ? main::get_size($_[0]) : ($_[0]);
	my @used = main::get_size($_[1]);
	my $string = '';
	if ($avail[1] && $used[1]){
		if ( $avail[1] eq $used[1]){
			$string = "$used[0]/$avail[0] $used[1]";
		}
		else {
			$string = "$used[0] $used[1]/$avail[0] $avail[1]";
		}
	}
	elsif ($used[1]){
		$string = "$used[0]/[$avail[0]] $used[1]";
	}
	$string .= " ($_[2]%)" if $_[2];
	return $string;
}

# Raspberry pi only
sub gpu_ram_arm {
	eval $start if $b_log;
	my ($gpu_ram) = (0);
	if (my $program = main::check_program('vcgencmd')){
		# gpu=128M
		# "VCHI initialization failed" - you need to add video group to your user
		my $working = (main::grabber("$program get_mem gpu 2>/dev/null"))[0];
		$working = (split(/\s*=\s*/, $working))[1] if $working;
		$gpu_ram = main::translate_size($working) if $working;
	}
	main::log_data('data',"gpu ram: $gpu_ram") if $b_log;
	eval $end if $b_log;
	return $gpu_ram;
}
}

# args: 0: module to get version of
sub get_module_version {
	eval $start if $b_log;
	my ($module) = @_;
	return if !$module;
	my ($version);
	my $path = "/sys/module/$module/version";
	if (-r $path){
		$version = reader($path,'',0);
	}
	elsif (-f "/sys/module/$module/uevent"){
		$version = 'kernel';
	}
	# print "version:$version\n";
	if (!$version){
		if (my $path = check_program('modinfo')){
			my @data = grabber("$path $module 2>/dev/null");
			$version = awk(\@data,'^version',2,':\s+') if @data;
		}
	}
	$version ||= '';
	eval $end if $b_log;
	return $version;
}

## PackageData
# Note: this outputs the key/value pairs ready to go and is
# called from either -r or -Ix, -r precedes. 
{