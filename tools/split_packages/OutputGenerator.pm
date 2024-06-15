package OutputGenerator;
my ($items,$subs);

sub generate {
	eval $start if $b_log;
	my ($item,%checks);
	PsData::set() if !$loaded{'ps-data'};
	main::set_sysctl_data() if $use{'sysctl'};
	main::set_dboot_data() if $bsd_type && !$loaded{'dboot'};
	# note: ps aux loads before logging starts, so create debugger data here
	if ($b_log){
		# With logging, we already get ps wwwaux so no need to get it again here
		main::log_data('dump','@ps_cmd',\@ps_cmd);
	}
	print Data::Dumper::Dumper \@ps_cmd if $dbg[61];
	if ($show{'short'}){
		$item = short_output();
		assign_data($item);
	}
	else {
		if ($show{'system'}){
			$item = system_item();
			assign_data($item);
		}
		if ($show{'machine'}){
			DmidecodeData::set(\$checks{'dmi'}) if $use{'dmidecode'} && !$checks{'dmi'}; 
			$item = item_handler('Machine','machine');
			assign_data($item);
		}
		if ($show{'battery'}){
			DmidecodeData::set(\$checks{'dmi'}) if $use{'dmidecode'} && !$checks{'dmi'}; 
			$item = item_handler('Battery','battery');
			if ($item || $show{'battery-forced'}){
				assign_data($item);
			}
		}
		if ($show{'ram'}){
			DmidecodeData::set(\$checks{'dmi'}) if $use{'dmidecode'} && !$checks{'dmi'}; 
			$item = item_handler('Memory','ram');
			assign_data($item);
		}
		if ($show{'slot'}){
			DmidecodeData::set(\$checks{'dmi'}) if $use{'dmidecode'} && !$checks{'dmi'}; 
			$item = item_handler('PCI Slots','slot');
			assign_data($item);
		}
		if ($show{'cpu'} || $show{'cpu-basic'}){
			DeviceData::set(\$checks{'device'}) if %risc && !$checks{'device'};
			DmidecodeData::set(\$checks{'dmi'}) if $use{'dmidecode'} && !$checks{'dmi'}; 
			my $arg = ($show{'cpu-basic'}) ? 'basic' : 'full' ;
			$item = item_handler('CPU','cpu',$arg);
			assign_data($item);
		}
		if ($show{'graphic'}){
			UsbData::set(\$checks{'usb'}) if !$checks{'usb'};
			DeviceData::set(\$checks{'device'}) if !$checks{'device'}; 
			$item = item_handler('Graphics','graphic');
			assign_data($item);
		}
		if ($show{'audio'}){
			UsbData::set(\$checks{'usb'}) if !$checks{'usb'};
			DeviceData::set(\$checks{'device'}) if !$checks{'device'}; 
			$item = item_handler('Audio','audio');
			assign_data($item);
		}
		if ($show{'network'}){
			UsbData::set(\$checks{'usb'}) if !$checks{'usb'};
			DeviceData::set(\$checks{'device'}) if !$checks{'device'}; 
			IpData::set() if ($show{'ip'} || ($bsd_type && $show{'network-advanced'}));
			$item = item_handler('Network','network');
			assign_data($item);
		}
		if ($show{'bluetooth'}){
			UsbData::set(\$checks{'usb'}) if !$checks{'usb'};
			DeviceData::set(\$checks{'device'}) if !$checks{'device'}; 
			$item = item_handler('Bluetooth','bluetooth');
			assign_data($item);
		}
		if ($show{'logical'}){
			$item = item_handler('Logical','logical');
			assign_data($item);
		}
		if ($show{'raid'}){
			DeviceData::set(\$checks{'device'}) if !$checks{'device'}; 
			$item = item_handler('RAID','raid');
			assign_data($item);
		}
		if ($show{'disk'} || $show{'disk-basic'} || $show{'disk-total'} || $show{'optical'}){
			UsbData::set(\$checks{'usb'}) if !$checks{'usb'};
			$item = item_handler('Drives','disk');
			assign_data($item);
		}
		if ($show{'partition'} || $show{'partition-full'}){
			$item = item_handler('Partition','partition');
			assign_data($item);
		}
		if ($show{'swap'}){
			$item = item_handler('Swap','swap');
			assign_data($item);
		}
		if ($show{'unmounted'}){
			$item = item_handler('Unmounted','unmounted');
			assign_data($item);
		}
		if ($show{'usb'}){
			UsbData::set(\$checks{'usb'}) if !$checks{'usb'};
			$item = item_handler('USB','usb');
			assign_data($item);
		}
		if ($show{'sensor'}){
			$item = item_handler('Sensors','sensor');
			assign_data($item);
		}
		if ($show{'repo'}){
			$item = item_handler('Repos','repo');
			assign_data($item);
		}
		if ($show{'process'}){
			$item = item_handler('Processes','process');
			assign_data($item);
		}
		if ($show{'weather'}){
			$item = item_handler('Weather','weather');
			assign_data($item);
		}
		if ($show{'info'}){
			$item = info_item();
			assign_data($item);
		}
	}
	if ($output_type ne 'screen'){
		main::output_handler($items);
	}
	eval $end if $b_log;
}

## Short, Info, System Items ##
sub short_output {
	eval $start if $b_log;
	my $num = 0;
	my $kernel_os = ($bsd_type) ? 'OS' : 'Kernel';
	my ($cpu_string,$speed,$speed_key,$type) = ('','','speed','');
 	my $cpu = CpuItem::get('short');
 	if (ref $cpu eq 'ARRAY' && scalar @$cpu > 1){
		$type = ($cpu->[2]) ? " (-$cpu->[2]-)" : '';
		($speed,$speed_key) = ('','');
		if ($cpu->[6]){
			$speed_key = "$cpu->[3]/$cpu->[5]";
			$speed = "$cpu->[4]/$cpu->[6] MHz";
		}
		else {
			$speed_key = $cpu->[3];
			$speed = "$cpu->[4] MHz";
		}
		$cpu->[1] ||= main::message('cpu-model-null');
		$cpu_string = $cpu->[0] . ' ' . $cpu->[1] . $type;
	}
	elsif ($bsd_type){
		if ($alerts{'sysctl'}->{'action'}){
			if ($alerts{'sysctl'}->{'action'} ne 'use'){
				$cpu_string = "sysctl $alerts{'sysctl'}->{'action'}";
				$speed = "sysctl $alerts{'sysctl'}->{'action'}";
			}
			else {
				$cpu_string = 'bsd support coming';
				$speed = 'bsd support coming';
			}
		}
	}
	$speed ||= 'N/A'; # totally unexpected situation, what happened?
	my $disk = DriveItem::get('short');
	# print Dumper \@disk;
	my $disk_string = 'N/A';
	my ($size,$used) = ('','');
	my ($size_holder,$used_holder);
	if (ref $disk eq 'ARRAY' && @$disk){
		$size = ($disk->[0]{'logical-size'}) ? $disk->[0]{'logical-size'} : $disk->[0]{'size'};
		# must be > 0
		if ($size && main::is_numeric($size)){
			$size_holder = $size;
			$size = main::get_size($size,'string');
		}
		$used = $disk->[0]{'used'};
		if ($used && main::is_numeric($disk->[0]{'used'})){
			$used_holder = $disk->[0]{'used'};
			$used = main::get_size($used,'string');
		}
		# in some fringe cases size can be 0 so only assign 'N/A' if no percents etc
		if ($size_holder && $used_holder){
			my $percent = ' (' . sprintf("%.1f", $used_holder/$size_holder*100) . '% used)';
			$disk_string = "$size$percent";
		}
		else {
			$size ||= main::message('disk-size-0');
			$disk_string = "$used/$size";
		}
	}
	my $memory = MemoryData::get('short');
	$memory = 'N/A' if !$memory; 
 	# print join('; ', @cpu), " sleep: $cpu_sleep\n";
 	if (!$loaded{'shell-data'} && $ppid && (!$b_irc || !$client{'name-print'})){
		ShellData::set();
	}
	my $client = $client{'name-print'};
	my $client_shell = ($b_irc) ? 'Client' : 'Shell';
	if ($client{'version'}){
		$client .= ' ' . $client{'version'};
	}
	my $data = [{
	main::key($num++,0,0,'CPU') => $cpu_string,
	main::key($num++,0,0,$speed_key) => $speed,
	main::key($num++,0,0,$kernel_os) => join(' ', @{main::get_kernel_data()}),
	main::key($num++,0,0,'Up') => main::get_uptime(),
	main::key($num++,0,0,'Mem') => $memory,
	main::key($num++,0,0,'Storage') => $disk_string,
	# could make -1 for ps aux itself, -2 for ps aux and self
	main::key($num++,0,0,'Procs') => scalar @ps_aux,
	main::key($num++,0,0,$client_shell) => $client,
	main::key($num++,0,0,$self_name) => main::get_self_version(),
	},];
	eval $end if $b_log;
	return {
	main::key($prefix,1,0,'SHORT') => $data,
	};
}

sub info_item {
	eval $start if $b_log;
	my $num = 0;
	my $running_in = '';
	my $data_name = main::key($prefix++,1,0,'Info');
	my ($index);
	my ($available,$gpu_ram,$parent,$percent,$used) = ('',0,'','','');
	my $data = {
	$data_name => [{}],
	};
	$index = 0;
	if (!$loaded{'memory'}){
		main::MemoryData::row('info',$data->{$data_name}[$index],\$num,1);
		if ($gpu_ram){
			$data->{$data_name}[$index]{main::key($num++,0,2,'gpu')} = $gpu_ram;
		}
		$index++;
	}
	$data->{$data_name}[$index]{main::key($num++,0,1,'Processes')} = scalar @ps_aux;
	my $uptime = main::get_uptime();
	if ($bsd_type || $extra < 2){
		$data->{$data_name}[$index]{main::key($num++,1,1,'Uptime')} = $uptime;
	}
	if (!$bsd_type && $extra > 1){
		my $power = PowerData::get();
		$data->{$data_name}[$index]{main::key($num++,1,1,'Power')} = '';
		$data->{$data_name}[$index]{main::key($num++,0,2,'uptime')} = $uptime;
		if ($power->{'states-avail'}){
			$data->{$data_name}[$index]{main::key($num++,0,2,'states')} = $power->{'states-avail'};
		}
		my $resumes = (defined $power->{'suspend-resumes'}) ? $power->{'suspend-resumes'} : undef;
		if ($extra > 2){
			my $suspend = (defined $power->{'suspend-active'}) ? $power->{'suspend-active'} : '';
			$data->{$data_name}[$index]{main::key($num++,1,2,'suspend')} = $suspend;
			if ($b_admin && $power->{'suspend-avail'}){
				$data->{$data_name}[$index]{main::key($num++,0,3,'avail')} = $power->{'suspend-avail'};
			}
			if (defined $resumes){
				$data->{$data_name}[$index]{main::key($num++,0,3,'wakeups')} = $resumes;
				if ($b_admin && $power->{'suspend-fails'}){
					$data->{$data_name}[$index]{main::key($num++,0,3,'fails')} = $power->{'suspend-fails'};
				}
			}
			if (defined $power->{'hibernate-active'}){
				$data->{$data_name}[$index]{main::key($num++,1,2,'hibernate')} = $power->{'hibernate-active'};
				if ($b_admin && $power->{'hibernate-avail'}){
					$data->{$data_name}[$index]{main::key($num++,0,3,'avail')} = $power->{'hibernate-avail'};
				}
				if ($b_admin && $power->{'hibernate-image-size'}){
					$data->{$data_name}[$index]{main::key($num++,0,3,'image')} = $power->{'hibernate-image-size'};
				}
			}
			if ($b_admin){
				PsData::set_power();
				if (@{$ps_data{'power-services'}}){
					my $services;
					main::make_list_value($ps_data{'power-services'},\$services,',','sort');
					$data->{$data_name}[$index]{main::key($num++,0,2,'services')} = $services;
				}
			}
		}
		else {
			if (defined $resumes){
				$data->{$data_name}[$index]{main::key($num++,0,2,'wakeups')} = $resumes;
			}
		}
	}
	if ((!$b_display || $force{'display'}) || $extra > 0){
		my $init = InitData::get();
		my $init_type = ($init->{'init-type'}) ? $init->{'init-type'}: 'N/A';
		$data->{$data_name}[$index]{main::key($num++,1,1,'Init')} = $init_type;
		if ($extra > 1){
			my $init_version = ($init->{'init-version'}) ? $init->{'init-version'}: 'N/A';
			$data->{$data_name}[$index]{main::key($num++,0,2,'v')} = $init_version;
		}
		if ($init->{'rc-type'}){
			$data->{$data_name}[$index]{main::key($num++,1,2,'rc')} = $init->{'rc-type'};
			if ($init->{'rc-version'}){
				$data->{$data_name}[$index]{main::key($num++,0,3,'v')} = $init->{'rc-version'};
			}
		}
		if ($init->{'runlevel'}){
			my $key = ($init->{'init-type'} && $init->{'init-type'} eq 'systemd') ? 'target' : 'runlevel';
			$data->{$data_name}[$index]{main::key($num++,1,2,$key)} = $init->{'runlevel'};
		}
		if ($extra > 1){
			if ($init->{'default'}){
				$data->{$data_name}[$index]{main::key($num++,0,3,'default')} = $init->{'default'};
			}
			if ($b_admin && (my $tool = ServiceData::get('tool',''))){
				$data->{$data_name}[$index]{main::key($num++,0,2,'tool')} = $tool;
				undef %service_tool;
			}
		}
	}
	$index++ if $extra > 0;
	if ($extra > 0 && !$loaded{'package-data'}){
		my $packages = PackageData::get('inner',\$num);
		
		for (keys %$packages){
			$data->{$data_name}[$index]{$_} = $packages->{$_};
		}
	}
	if ($extra > 0){
		my (%cc,$path);
		foreach my $compiler (qw(clang gcc zigcc)){
			my $comps = main::get_compiler_data($compiler);
			if (@$comps){
				$cc{$compiler}->{'version'} = shift @$comps;
				if ($extra > 1 && @$comps){
					$cc{$compiler}->{'alt'} = join('/', @$comps);
				}
				$cc{$compiler}->{'version'} ||= 'N/A'; # should not be needed after fix but leave in case undef
			}
		}
		my $cc_value = ($cc{'clang'} || $cc{'gcc'} || $cc{'zigcc'}) ? '': 'N/A';
		$data->{$data_name}[$index]{main::key($num++,1,1,'Compilers')} = $cc_value;
		foreach my $compiler (qw(clang gcc zigcc)){
			if ($cc{$compiler}){
				$data->{$data_name}[$index]{main::key($num++,0,2,$compiler)} = $cc{$compiler}->{'version'};
				if ($extra > 1 && $cc{$compiler}->{'alt'}){
					$data->{$data_name}[$index]{main::key($num++,0,3,'alt')} = $cc{$compiler}->{'alt'};
				}
			}
		}
	}
	# $index++ if $extra > 1 && !$loaded{'shell-data'};
	if (!$loaded{'shell-data'} && $ppid && (!$b_irc || !$client{'name-print'})){
		ShellData::set();
	}
	my $client_shell = ($b_irc) ? 'Client' : 'Shell';
	my $client = $client{'name-print'};
	if (!$b_irc && $extra > 1){
		# some bsds don't support -f option to get PPPID
		# note: root/su - does not have $DISPLAY usually
		if ($b_display && !$force{'display'} && $ppid && $client{'pppid'}){
			$parent = ShellData::shell_launcher();
		}
		else {
			ShellData::tty_number() if !$loaded{'tty-number'};
			if ($client{'tty-number'} ne ''){
				my $tty_type = '';
				if ($client{'tty-number'} =~ /^[a-f0-9]+$/i){
					$tty_type = 'tty ';
				}
				elsif ($client{'tty-number'} =~ /pts/i){
					$tty_type = 'pty ';
				}
				$parent = "$tty_type$client{'tty-number'}";
			}
		}
		# can be tty 0 so test for defined
		$running_in = $parent if $parent;
		if ($extra > 2 && $running_in && ShellData::ssh_status()){
			$running_in .= ' (SSH)';
		}
		if ($extra > 2 && $client{'su-start'}){
			$client .= " ($client{'su-start'})";
		}
	}
	$data->{$data_name}[$index]{main::key($num++,1,1,$client_shell)} =  $client;
	if ($extra > 0 && $client{'version'}){
		$data->{$data_name}[$index]{main::key($num++,0,2,'v')} = $client{'version'};
	}
	if (!$b_irc){
		if ($extra > 2 && $client{'default-shell'}){
			$data->{$data_name}[$index]{main::key($num++,1,2,'default')} = $client{'default-shell'};
			$data->{$data_name}[$index]{main::key($num++,0,3,'v')} = $client{'default-shell-v'} if $client{'default-shell-v'};
		}
		if ($running_in){
			$data->{$data_name}[$index]{main::key($num++,0,2,'running-in')} = $running_in;
		}
	}
	$data->{$data_name}[$index]{main::key($num++,0,1,$self_name)} = main::get_self_version();
	eval $end if $b_log;
	return $data;
}

sub system_item {
	eval $start if $b_log;
	my ($cont_desk,$ind_dm,$num) = (1,2,0);
	my ($index);
	my $data_name = main::key($prefix++,1,0,'System');
	my ($desktop,$desktop_key,$toolkit,$wm) = ('','Desktop','','');
	my ($cs_curr,$cs_avail,@desktop_data,$de_components,$de_info,$de_info_v,
	$de_version,$tools_running,$tools_avail,$tk_version,$wm_version);
	my $data = {
	$data_name => [{}],
	};
	$index = 0;
	if ($show{'host'}){
		$data->{$data_name}[$index]{main::key($num++,0,1,'Host')} = main::get_hostname();
	}
	my $dms = DmData::get();
	my $dm_key = (!$dms->{'dm'} && $dms->{'lm'}) ? 'LM' : 'DM';
	my $kernel_data = main::get_kernel_data();
	$data->{$data_name}[$index]{main::key($num++,1,1,'Kernel')} = $kernel_data->[0];
	$data->{$data_name}[$index]{main::key($num++,0,2,'arch')} = $kernel_data->[1];
	$data->{$data_name}[$index]{main::key($num++,0,2,'bits')} = main::get_kernel_bits();
	if ($extra > 0){
		my $compiler = KernelCompiler::get(); # get compiler data
		if (scalar @$compiler != 2){
			@$compiler = ('N/A', '');
		}
		$data->{$data_name}[$index]{main::key($num++,1,2,'compiler')} = $compiler->[0];
		# if no compiler, obviously no version, so don't waste space showing.
		if ($compiler->[0] ne 'N/A'){
			$compiler->[1] ||= 'N/A';
			$data->{$data_name}[$index]{main::key($num++,0,3,'v')} = $compiler->[1];
		}
	}
	if ($extra > 2){
		main::get_kernel_clocksource(\$cs_curr,\$cs_avail);
		$cs_curr ||= 'N/A';
		$data->{$data_name}[$index]{main::key($num++,1,2,'clocksource')} = $cs_curr;
		if ($b_admin && $cs_avail){
			$data->{$data_name}[$index]{main::key($num++,0,3,'avail')} = $cs_avail;
		}
	}
	if ($b_admin && (my $params = KernelParameters::get())){
		# print "$params\n";
		if ($use{'filter-label'}){
			$params = main::filter_partition('system', $params, 'label');
		}
		if ($use{'filter-uuid'}){
			$params = main::filter_partition('system', $params, 'uuid');
		}
		$data->{$data_name}[$index]{main::key($num++,0,2,'parameters')} = $params;
		
	}
	$index++;
	# note: tty can have the value of 0 but the two tools 
	# return '' if undefined, so we test for explicit ''
	if ($b_display){
		my $desktop_data = DesktopData::get();
		$desktop = $desktop_data->[0] if $desktop_data->[0];
		if ($desktop){
			$de_version = ($desktop_data->[1]) ? $desktop_data->[1] : 'N/A';
			if ($extra > 0 && $desktop_data->[2]){
				$toolkit = $desktop_data->[2];
				if ($desktop_data->[1] || $desktop_data->[3]){
					$tk_version = ($desktop_data->[3]) ? $desktop_data->[3] : 'N/A';
				}
			}
			if ($b_admin && $desktop_data->[9] && $desktop_data->[10]){
				$de_info = $desktop_data->[9];
				$de_info_v = $desktop_data->[10];
			}
		}
		# don't print the desktop if it's a wm and the same
		if ($extra > 1 && $desktop_data->[5] && 
		(!$desktop_data->[0] || $desktop_data->[5] =~ /^(deepin.+|gnome[\s_-]shell|budgie.+)$/i || 
		index(lc($desktop_data->[5]),lc($desktop_data->[0])) == -1)){
			$wm = $desktop_data->[5];
			$wm_version = $desktop_data->[6] if $extra > 2 && $desktop_data->[6];
		}
		if ($extra > 2 && $desktop_data->[4]){
			$de_components = $desktop_data->[4];
		}
		if ($extra > 2 && $desktop_data->[7]){
			$tools_running = $desktop_data->[7];
		}
		if ($b_admin && $desktop_data->[8]){
			$tools_avail = $desktop_data->[8];
		}
	}
	if (!$b_display || (!$desktop && $b_root)){
		ShellData::tty_number() if !$loaded{'tty-number'};
		my $tty = $client{'tty-number'};
		if (!$desktop){
			$de_components = '';
		}
		# it is defined, as ''
		if ($tty eq '' && $client{'console-irc'}){
			ShellData::console_irc_tty() if !$loaded{'con-irc-tty'};
			$tty = $client{'con-irc-tty'};
		}
		if ($tty ne ''){
			my $tty_type = '';
			if ($tty =~ /^[a-f0-9]+$/i){
				$tty_type = 'tty ';
			}
			elsif ($tty =~ /pts/i){
				$tty_type = 'pty ';
			}
			$desktop = "$tty_type$tty";
		}
		$desktop_key = 'Console';
		$ind_dm = 1;
		$cont_desk = 0;
	}
	else {
		$dm_key = lc($dm_key);
	}
	$desktop ||= 'N/A';
	$data->{$data_name}[$index]{main::key($num++,$cont_desk,1,$desktop_key)} = $desktop;
	if ($b_display){
		if ( $de_version){
			$data->{$data_name}[$index]{main::key($num++,0,2,'v')} = $de_version;
		}
		if ($toolkit){
			$data->{$data_name}[$index]{main::key($num++,1,2,'tk')} = $toolkit;
			if ($tk_version){
				$data->{$data_name}[$index]{main::key($num++,0,3,'v')} = $tk_version;
			}
		}
		if ($de_info){
			$data->{$data_name}[$index]{main::key($num++,1,2,'info')} = $de_info;
			$data->{$data_name}[$index]{main::key($num++,0,3,'v')} = $de_info_v;
		}
		if ($extra > 1){
			if ($wm){
				$data->{$data_name}[$index]{main::key($num++,1,2,'wm')} = $wm;
				if ($wm_version){
					$data->{$data_name}[$index]{main::key($num++,0,3,'v')} = $wm_version;
				}
			}
			if ($extra > 2){
				if ($de_components){
					$data->{$data_name}[$index]{main::key($num++,0,2,'with')} = $de_components;
				}
				if ($tools_running || $tools_avail){
					$tools_running ||= '';
					$data->{$data_name}[$index]{main::key($num++,1,2,'tools')} = $tools_running;
					if ($tools_avail){
						$data->{$data_name}[$index]{main::key($num++,0,3,'avail')} = $tools_avail;
					}
				}
				if (defined $ENV{'XDG_VTNR'}){
					$data->{$data_name}[$index]{main::key($num++,0,2,'vt')} = $ENV{'XDG_VTNR'};
				}
			}
		}
	}
	if ($extra > 1){
		# note: version only present if proper extra level so no need to test again
		if (%$dms || $desktop_key ne 'Console'){
			my $type = (!$dms->{'dm'} && $dms->{'lm'}) ? $dms->{'lm'}: $dms->{'dm'};
			if ($type && @$type && scalar @$type > 1){
				my $i = 0;
				$data->{$data_name}[$index]{main::key($num++,1,$ind_dm,$dm_key)} = '';
				foreach my $dm_data (@{$type}){
					$i++;
					$data->{$data_name}[$index]{main::key($num++,1,($ind_dm + 1),$i)} = $dm_data->[0];
					if ($dm_data->[1]){
						$data->{$data_name}[$index]{main::key($num++,0,($ind_dm + 2),'v')} = $dm_data->[1];
					}
					if ($dm_data->[2]){
						$data->{$data_name}[$index]{main::key($num++,0,($ind_dm + 2),'note')} = $dm_data->[2];
					}
				}
			}
			else {
				my $dm = ($type && $type->[0][0]) ? $type->[0][0] : 'N/A';
				$data->{$data_name}[$index]{main::key($num++,1,$ind_dm,$dm_key)} = $dm;
				if ($type && @{$type} && $type->[0][1]){
					$data->{$data_name}[$index]{main::key($num++,0,($ind_dm + 1),'v')} = $type->[0][1];
				}
			}
		}
	}
	# if ($extra > 2 && $desktop_key ne 'Console'){
	#	my $tty = ShellData::tty_number() if !$loaded{'tty-number'};
	#	$data->{$data_name}[$index]{main::key($num++,0,1,'vc')} = $tty if $tty ne '';
	# }
	my $distro_key = ($bsd_type) ? 'OS': 'Distro';
	my $distro = DistroData::get();
	$distro->{'name'} ||= 'N/A';
	$data->{$data_name}[$index]{main::key($num++,1,1,$distro_key)} = $distro->{'name'};
	if ($extra > 0 && $distro->{'base'}){
		$data->{$data_name}[$index]{main::key($num++,0,2,'base')} = $distro->{'base'};
	}
	eval $end if $b_log;
	return $data;
}

## Item Processors ##
sub assign_data {
	return if !$_[0] || ref $_[0] ne 'HASH';
	if ($output_type eq 'screen'){
		main::print_data($_[0]);
	}
	else {
		push(@$items,$_[0]);
	}
}

sub item_handler {
	eval $start if $b_log;
	my ($key,$item,$arg) = @_;
	set_subs() if !$subs;
	my $rows = $subs->{$item}($arg);
	eval $end if $b_log;
	if (ref $rows eq 'ARRAY' && @$rows){
		return {main::key($prefix++,1,0,$key) => $rows};
	}
}

sub set_subs {
	$subs = {
	'audio' => \&AudioItem::get,
	'battery' => \&BatteryItem::get,
	'bluetooth' => \&BluetoothItem::get,
	'cpu' => \&CpuItem::get,
	'disk' => \&DriveItem::get,
	'graphic' => \&GraphicItem::get,
	'logical' => \&LogicalItem::get,
	'machine' => \&MachineItem::get,
	'network' => \&NetworkItem::get,
	'partition' => \&PartitionItem::get,
	'raid' => \&RaidItem::get,
	'ram' => \&RamItem::get,
	'repo' => \&RepoItem::get,
	'process' => \&ProcessItem::get,
	'sensor' => \&SensorItem::get,
	'slot' => \&SlotItem::get,
	'swap' => \&SwapItem::get,
	'unmounted' => \&UnmountedItem::get,
	'usb' => \&UsbItem::get,
	'weather' => \&WeatherItem::get,
	};
}
}

#######################################################################
#### LAUNCH
########################################################################

main(); ## From the End comes the Beginning

## note: this EOF is needed for self updater, triggers the full download ok