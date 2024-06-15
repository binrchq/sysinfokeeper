package SensorItem;
my $gpu_data = [];
my $sensors_raw = {};
my $max_fan = 15000;

sub get {
	eval $start if $b_log;
	my ($b_data,$b_ipmi,$b_no_lm,$b_no_sys);
	my ($message_type,$program,$val1,$sensors);
	my ($key1,$num,$rows) = ('Message',0,[]);
	my $source = 'sensors'; # will trip some type output if ipmi + another type
	# we're allowing 1 or 2 ipmi tools, first the gnu one, then the 
	# almost certain to be present in BSDs
	if ($fake{'ipmi'} || (main::globber('/dev/ipmi**') && 
	(($program = main::check_program('ipmi-sensors')) ||
	($program = main::check_program('ipmitool'))))){
		if ($fake{'ipmi'} || $b_root){
			$sensors = ipmi_data($program);
			$b_data = sensors_output($rows,'ipmi',$sensors);
			if (!$b_data){
				$val1 = main::message('sensor-data-ipmi');
				push(@$rows,{
				main::key($num++,1,1,'Src') => 'ipmi',
				main::key($num++,0,1,$key1) => $val1,
				});
			}
		}
		else {
			$key1 = 'Permissions';
			$val1 = main::message('sensor-data-ipmi-root');
			push(@$rows,{
			main::key($num++,1,1,'Src') => 'ipmi',
			main::key($num++,0,2,$key1) => $val1,
			});
		}
		$b_ipmi = 1;
	}
	$b_data = 0;
	if ($bsd_type){
		if ($sysctl{'sensor'}){
			$sensors = sysctl_data();
			$source = 'sysctl' if $b_ipmi;
			$b_data = sensors_output($rows,$source,$sensors);
			if (!$b_data){
				$source = 'sysctl';
				$val1 = main::message('sensor-data-bsd',$uname[0]);
			}
		}
		else {
			if ($bsd_type =~ /^(free|open)bsd/){
				$source = 'sysctl';
				$val1 = main::message('sensor-data-bsd-ok');
			}
			else {
				$source = 'N/A';
				$val1 = main::message('sensor-data-bsd-unsupported');
			}
		}
	}
	else {
		if (!$force{'sensors-sys'} && 
		($fake{'sensors'} || $alerts{'sensors'}->{'action'} eq 'use')){
			load_lm_sensors();
			$sensors = linux_sensors_data();
			$source = 'lm-sensors' if $b_ipmi; # trips per sensor type output
			$b_data = sensors_output($rows,$source,$sensors);
			# print "here 1\n";
			$b_no_lm = 1 if !$b_data;
		}
		# given recency of full /sys data, we want to prefer lm-sensors for a long time
		# and use /sys as a fallback. This will handle servers, which often do not
		# have lm-sensors installed, but do have /sys hwmon data.
		if (!$b_data && -d '/sys/class/hwmon'){
			load_sys_data();
			$sensors = linux_sensors_data();
			$source = '/sys'; # trips per sensor type output
			$b_data = sensors_output($rows,$source,$sensors);
			# print "here 2\n";
			$b_no_sys = 1 if !$b_data;
		}
		if (!$b_data){
			if ($b_no_lm || $b_no_sys){
				if ($b_no_lm && $b_no_sys){
					$source = 'lm-sensors+/sys';
					$val1 = main::message('sensor-data-sys-lm');
				}
				elsif ($b_no_lm){
					$source = 'lm-sensors';
					$val1 = main::message('sensor-data-lm-sensors');
				}
				else {
					$val1 = main::message('sensor-data-sys');
				}
			}
			elsif (!$fake{'sensors'} && $alerts{'sensors'}->{'action'} ne 'use'){
				# print "here 3\n";
				$source = 'lm-sensors';
				$key1 = $alerts{'sensors'}->{'action'};
				$key1 = ucfirst($key1);
				$val1 = $alerts{'sensors'}->{'message'};
			}
			else {
				$source = 'N/A';
				$val1 = main::message('sensors-data-linux');
			}
		}
	}
	if (!$b_data){
		push(@$rows,{
		main::key($num++,1,1,'Src') => $source,
		main::key($num++,0,2,$key1) => $val1,
		});
	}
	eval $end if $b_log;
	return $rows;
}

sub sensors_output {
	eval $start if $b_log;
	my ($rows,$source,$sensors) = @_;
	my ($b_result,@fan_default,@fan_main);
	my $fan_number = 0;
	my $num = 0;
	my $j = scalar @$rows;
	if (!$loaded{'gpu-data'} && 
	($source eq 'sensors' || $source eq 'lm-sensors' || $source eq '/sys')){
		gpu_sensor_data();
	}
	# gpu sensors data might be present even if standard sensors data wasn't
	return if !%$sensors && !@$gpu_data;
	$b_result = 1; ## need to trip data found conditions
	my $temp_unit  = (defined $sensors->{'temp-unit'}) ? " $sensors->{'temp-unit'}": '';
	my $cpu_temp = (defined $sensors->{'cpu-temp'}) ? $sensors->{'cpu-temp'} . $temp_unit: 'N/A';
	my $mobo_temp = (defined $sensors->{'mobo-temp'}) ? $sensors->{'mobo-temp'} . $temp_unit: 'N/A';
	my $cpu1_key = ($sensors->{'cpu2-temp'}) ? 'cpu-1': 'cpu';
	my ($l1,$l2,$l3) = (1,2,3);
	if ($source ne 'sensors'){
		$rows->[$j]{main::key($num++,1,1,'Src')} = $source;
		($l1,$l2,$l3) = (2,3,4);
	}
	$rows->[$j]{main::key($num++,1,$l1,'System Temperatures')} = '';
	$rows->[$j]{main::key($num++,0,$l2,$cpu1_key)} = $cpu_temp;
	if ($sensors->{'cpu2-temp'}){
		$rows->[$j]{main::key($num++,0,$l2,'cpu-2')} = $sensors->{'cpu2-temp'} . $temp_unit;
	}
	if ($sensors->{'cpu3-temp'}){
		$rows->[$j]{main::key($num++,0,$l2,'cpu-3')} = $sensors->{'cpu3-temp'} . $temp_unit;
	}
	if ($sensors->{'cpu4-temp'}){
		$rows->[$j]{main::key($num++,0,$l2,'cpu-4')} = $sensors->{'cpu4-temp'} . $temp_unit;
	}
	if (defined $sensors->{'pch-temp'}){
		my $pch_temp = $sensors->{'pch-temp'} . $temp_unit;
		$rows->[$j]{main::key($num++,0,$l2,'pch')} = $pch_temp;
	}
	$rows->[$j]{main::key($num++,0,$l2,'mobo')} = $mobo_temp;
	if (defined $sensors->{'sodimm-temp'}){
		my $sodimm_temp = $sensors->{'sodimm-temp'} . $temp_unit;
		$rows->[$j]{main::key($num++,0,$l2,'sodimm')} = $sodimm_temp;
	}
	if (defined $sensors->{'psu-temp'}){
		my $psu_temp = $sensors->{'psu-temp'} . $temp_unit;
		$rows->[$j]{main::key($num++,0,$l2,'psu')} = $psu_temp;
	}
	if (defined $sensors->{'ambient-temp'}){
		my $ambient_temp = $sensors->{'ambient-temp'} . $temp_unit;
		$rows->[$j]{main::key($num++,0,$l2,'ambient')} = $ambient_temp;
	}
	if (scalar @$gpu_data == 1 && defined $gpu_data->[0]{'temp'}){
		my $gpu_temp = $gpu_data->[0]{'temp'};
		my $gpu_type = $gpu_data->[0]{'type'};
		my $gpu_unit = (defined  $gpu_data->[0]{'temp-unit'} && $gpu_temp) ? " $gpu_data->[0]{'temp-unit'}" : ' C';
		$rows->[$j]{main::key($num++,1,$l2,'gpu')} = $gpu_type;
		$rows->[$j]{main::key($num++,0,$l3,'temp')} = $gpu_temp . $gpu_unit;
		if ($extra > 1 && $gpu_data->[0]{'temp-mem'}){
			$rows->[$j]{main::key($num++,0,$l3,'mem')} = $gpu_data->[0]{'temp-mem'} . $gpu_unit;
		}
	}
	$j = scalar @$rows;
	@fan_main = @{$sensors->{'fan-main'}} if $sensors->{'fan-main'};
	@fan_default = @{$sensors->{'fan-default'}} if $sensors->{'fan-default'};
	my $fan_def = (!@fan_main && !@fan_default) ? 'N/A' : '';
	$rows->[$j]{main::key($num++,1,$l1,'Fan Speeds (rpm)')} = $fan_def;
	my $b_cpu = 0;
	for (my $i = 0; $i < scalar @fan_main; $i++){
		next if $i == 0;# starts at 1, not 0
		if (defined $fan_main[$i]){
			if ($i == 1 || ($i == 2 && !$b_cpu)){
				$rows->[$j]{main::key($num++,0,$l2,'cpu')} = $fan_main[$i];
				$b_cpu = 1;
			}
			elsif ($i == 2 && $b_cpu){
				$rows->[$j]{main::key($num++,0,$l2,'mobo')} = $fan_main[$i];
			}
			elsif ($i == 3){
				$rows->[$j]{main::key($num++,0,$l2,'psu')} = $fan_main[$i];
			}
			elsif ($i == 4){
				$rows->[$j]{main::key($num++,0,$l2,'sodimm')} = $fan_main[$i];
			}
			elsif ($i > 4){
				$fan_number = $i - 4;
				$rows->[$j]{main::key($num++,0,$l2,"case-$fan_number")} = $fan_main[$i];
			}
		}
	}
	for (my $i = 0; $i < scalar @fan_default; $i++){
		next if $i == 0;# starts at 1, not 0
		if (defined $fan_default[$i]){
			$rows->[$j]{main::key($num++,0,$l2,"fan-$i")} = $fan_default[$i];
		}
	}
	$rows->[$j]{main::key($num++,0,$l2,'psu')} = $sensors->{'fan-psu'} if defined $sensors->{'fan-psu'};
	$rows->[$j]{main::key($num++,0,$l2,'psu-1')} = $sensors->{'fan-psu1'} if defined $sensors->{'fan-psu1'};
	$rows->[$j]{main::key($num++,0,$l2,'psu-2')} = $sensors->{'fan-psu2'} if defined $sensors->{'fan-psu2'};
	# note: so far, only nvidia-settings returns speed, and that's in percent
	if (scalar @$gpu_data == 1 && defined $gpu_data->[0]{'fan-speed'}){
		my $gpu_fan = $gpu_data->[0]{'fan-speed'} . $gpu_data->[0]{'speed-unit'};
		my $gpu_type = $gpu_data->[0]{'type'};
		$rows->[$j]{main::key($num++,1,$l2,'gpu')} = $gpu_type;
		$rows->[$j]{main::key($num++,0,$l3,'fan')} = $gpu_fan;
	}
	if (scalar @$gpu_data > 1){
		$j = scalar @$rows;
		$rows->[$j]{main::key($num++,1,$l1,'GPU')} = '';
		my $gpu_unit = (defined $gpu_data->[0]{'temp-unit'}) ? " $gpu_data->[0]{'temp-unit'}" : ' C';
		foreach my $info (@$gpu_data){
			# speed unit is either '' or %
			my $gpu_fan = (defined $info->{'fan-speed'}) ? $info->{'fan-speed'} . $info->{'speed-unit'}: undef;
			my $gpu_type = $info->{'type'};
			my $gpu_temp = (defined $info->{'temp'}) ? $info->{'temp'} . $gpu_unit: 'N/A';
			$rows->[$j]{main::key($num++,1,$l2,'device')} = $gpu_type;
			if (defined $info->{'screen'}){
				$rows->[$j]{main::key($num++,0,$l3,'screen')} = $info->{'screen'};
			}
			$rows->[$j]{main::key($num++,0,$l3,'temp')} = $gpu_temp;
			if ($extra > 1 && $info->{'temp-mem'}){
				$rows->[$j]{main::key($num++,0,$l3,'mem')} = $info->{'temp-mem'} . $gpu_unit;
			}
			if (defined $gpu_fan){
				$rows->[$j]{main::key($num++,0,$l3,'fan')} = $gpu_fan;
			}
			if ($extra > 2 && $info->{'watts'}){
				$rows->[$j]{main::key($num++,0,$l3,'watts')} = $info->{'watts'};
			}
			if ($extra > 2 && $info->{'volts-gpu'}){
				$rows->[$j]{main::key($num++,0,$l3,$info->{'volts-gpu'}[1])} = $info->{'volts-gpu'}[0];
			}
		}
	}
	if ($extra > 0 && ($source eq 'ipmi' || 
	($sensors->{'volts-12'} || $sensors->{'volts-5'} || $sensors->{'volts-3.3'} || 
	$sensors->{'volts-vbat'}))){
		$j = scalar @$rows;
		$sensors->{'volts-12'} ||= 'N/A';
		$sensors->{'volts-5'} ||= 'N/A';
		$sensors->{'volts-3.3'} ||= 'N/A';
		$sensors->{'volts-vbat'} ||= 'N/A';
		$rows->[$j]{main::key($num++,1,$l1,'Power')} = '';
		$rows->[$j]{main::key($num++,0,$l2,'12v')} = $sensors->{'volts-12'};
		$rows->[$j]{main::key($num++,0,$l2,'5v')} = $sensors->{'volts-5'};
		$rows->[$j]{main::key($num++,0,$l2,'3.3v')} = $sensors->{'volts-3.3'};
		$rows->[$j]{main::key($num++,0,$l2,'vbat')} = $sensors->{'volts-vbat'};
		if ($extra > 1 && $source eq 'ipmi'){
			$sensors->{'volts-dimm-p1'} ||= 'N/A';
			$sensors->{'volts-dimm-p2'} ||= 'N/A';
			if ($sensors->{'volts-dimm-p1'}){
				$rows->[$j]{main::key($num++,0,$l2,'dimm-p1')} = $sensors->{'volts-dimm-p1'};
			}
			if ($sensors->{'volts-dimm-p2'}){
				$rows->[$j]{main::key($num++,0,$l2,'dimm-p2')} = $sensors->{'volts-dimm-p2'};
			}
			if ($sensors->{'volts-soc-p1'}){
				$rows->[$j]{main::key($num++,0,$l2,'soc-p1')} = $sensors->{'volts-soc-p1'};
			}
			if ($sensors->{'volts-soc-p2'}){
				$rows->[$j]{main::key($num++,0,$l2,'soc-p2')} = $sensors->{'volts-soc-p2'};
			}
		}
		if (scalar @$gpu_data == 1 && $extra > 2 && 
		($gpu_data->[0]{'watts'} || $gpu_data->[0]{'volts-gpu'})){
			$rows->[$j]{main::key($num++,1,$l2,'gpu')} = $gpu_data->[0]{'type'};
			if ($gpu_data->[0]{'watts'}){
				$rows->[$j]{main::key($num++,0,$l3,'watts')} = $gpu_data->[0]{'watts'};
			}
			if ($gpu_data->[0]{'volts-gpu'}){
				$rows->[$j]{main::key($num++,0,$l3,$gpu_data->[0]{'volts-gpu'}[1])} = $gpu_data->[0]{'volts-gpu'}[0];
			}
		}
	}
	eval $end if $b_log;
	return $b_result;
}

sub ipmi_data {
	eval $start if $b_log;
	my ($program) = @_;
	my ($b_cpu_0,$cmd,$file,@data,$fan_working,@row,$speed,$sys_fan_nu,$temp_working,
	$working_unit);
	my ($b_ipmitool,$i_key,$i_value,$i_unit);
	my $sensors = {};
	if ($fake{'ipmi'}){
		## ipmitool ##
		# $file = "$fake_data_dir/sensors/ipmitool/ipmitool-sensors-archerseven-1.txt";$program='ipmitool';
		# $file = "$fake_data_dir/sensorsipmitool/ipmitool-sensors-epyc-1.txt";$program='ipmitool';
		# $file = "$fake_data_dir/sensorsipmitool/ipmitool-sensors-RK016013.txt";$program='ipmitool';
		# $file = "$fake_data_dir/sensorsipmitool/ipmitool-sensors-freebsd-offsite-backup.txt";
		# $file = "$fake_data_dir/sensorsipmitool/ipmitool-sensor-shom-1.txt";$program='ipmitool';
		# $file = "$fake_data_dir/sensorsipmitool/ipmitool-sensor-shom-2.txt";$program='ipmitool';
		# $file = "$fake_data_dir/sensorsipmitool/ipmitool-sensor-tyan-1.txt";$program='ipmitool';
		# ($b_ipmitool,$i_key,$i_value,$i_unit) = (1,0,1,2); # ipmitool sensors
		## ipmi-sensors ##
		# $file = "$fake_data_dir/sensorsipmitool/ipmi-sensors-epyc-1.txt";$program='ipmi-sensors';
		# $file = "$fake_data_dir/sensorsipmitool/ipmi-sensors-lathander.txt";$program='ipmi-sensors';
		# $file = "$fake_data_dir/sensorsipmitool/ipmi-sensors-zwerg.txt";$program='ipmi-sensors';
		# $file = "$fake_data_dir/sensorsipmitool/ipmi-sensors-arm-server-1.txt";$program='ipmi-sensors';
		# ($b_ipmitool,$i_key,$i_value,$i_unit) = (0,1,3,4); # ipmi-sensors
		# @data = main::reader($file);
	}
	else {
		if ($program =~ /ipmi-sensors$/){
			$cmd = $program;
			($b_ipmitool,$i_key,$i_value,$i_unit) = (0,1,3,4);
		}
		else { # ipmitool
			$cmd = "$program sensor"; # note: 'sensor' NOT 'sensors' !!
			($b_ipmitool,$i_key,$i_value,$i_unit) = (1,0,1,2);
		}
		@data = main::grabber("$cmd 2>/dev/null");
	}
	# print join("\n", @data), "\n";
	# shouldn't need to log, but saw a case with debugger ipmi data, but none here apparently
	main::log_data('dump','ipmi @data',\@data) if $b_log;
	return $sensors if !@data;
	foreach (@data){
		next if /^\s*$/;
		# print "$_\n";
		@row = split(/\s*\|\s*/, $_);
		# print "$row[$i_value]\n";
		next if !main::is_numeric($row[$i_value]);
		# print "$row[$i_key] - $row[$i_value]\n";
		if (!$sensors->{'mobo-temp'} && $row[$i_key] =~ /^(MB[\s_-]?TEMP[0-9]|System[\s_-]?Temp|System[\s_-]?Board([\s_-]?Temp)?)$/i){
			$sensors->{'mobo-temp'} = int($row[$i_value]);
			$working_unit = $row[$i_unit];
			$working_unit =~ s/degrees\s// if $b_ipmitool; 
			$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
		}
		elsif ($row[$i_key] =~ /^(System[\s_-]?)?(Ambient)([\s_-]?Temp)?$/i){
			$sensors->{'ambient-temp'} = int($row[$i_value]);
			$working_unit = $row[$i_unit];
			$working_unit =~ s/degrees\s// if $b_ipmitool; 
			$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
		}
		# Platform Control Hub (PCH), it is the X370 chip on the Crosshair VI Hero.
		# VRM: voltage regulator module
		# NOTE: CPU0_TEMP CPU1_TEMP is possible, unfortunately; CPU Temp Interf 
		elsif (!$sensors->{'cpu-temp'} && $row[$i_key] =~ /^CPU[\s_-]?([01])?([\s_](below[\s_]Tmax|Temp))?$/i){
			$b_cpu_0 = 1 if defined $1 && $1 == 0;
			$sensors->{'cpu-temp'} = int($row[$i_value]);
			$working_unit = $row[$i_unit];
			$working_unit =~ s/degrees\s// if $b_ipmitool; 
			$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
		}
		elsif ($row[$i_key] =~ /^CPU[\s_-]?([1-4])([\s_](below[\s_]Tmax|Temp))?$/i){
			$temp_working = $1;
			$temp_working++ if $b_cpu_0;
			$sensors->{"cpu${temp_working}-temp"} = int($row[$i_value]);
			$working_unit = $row[$i_unit];
			$working_unit =~ s/degrees\s// if $b_ipmitool; 
			$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
		}
		# for temp1/2 only use temp1/2 if they are null or greater than the last ones
		elsif ($row[$i_key] =~ /^(MB[\s_-]?TEMP1|Temp[\s_]1)$/i){
			$temp_working = int($row[$i_value]);
			$working_unit = $row[$i_unit];
			$working_unit =~ s/degrees\s// if $b_ipmitool; 
			if (!$sensors->{'temp1'} || (defined $temp_working && $temp_working > 0)){
				$sensors->{'temp1'} = $temp_working;
			}
			$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
		}
		elsif ($row[$i_key] =~ /^(MB[_]?TEMP2|Temp[\s_]2)$/i){
			$temp_working = int($row[$i_value]);
			$working_unit = $row[$i_unit];
			$working_unit =~ s/degrees\s// if $b_ipmitool; 
			if (!$sensors->{'temp2'} || (defined $temp_working && $temp_working > 0)){
				$sensors->{'temp2'} = $temp_working;
			}
			$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
		}
		# temp3 is only used as an absolute override for systems with all 3 present
		elsif ($row[$i_key] =~ /^(MB[_]?TEMP3|Temp[\s_]3)$/i){
			$temp_working = int($row[$i_value]);
			$working_unit = $row[$i_unit];
			$working_unit =~ s/degrees\s// if $b_ipmitool; 
			if (!$sensors->{'temp3'} || (defined $temp_working && $temp_working > 0)){
				$sensors->{'temp3'} = $temp_working;
			}
			$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
		}
		elsif (!$sensors->{'sodimm-temp'} && ($row[$i_key] =~ /^(DIMM[-_]([A-Z][0-9]+[-_])?[A-Z]?[0-9]+[A-Z]?)$/i ||
		$row[$i_key] =~ /^DIMM\s?[0-9]+ (Area|Temp).*/)){
			$sensors->{'sodimm-temp'} = int($row[$i_value]);
			$working_unit = $row[$i_unit];
			$working_unit =~ s/degrees\s// if $b_ipmitool; 
			$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
		}
		# note: can be cpu fan:, cpu fan speed:, etc.
		elsif ($row[$i_key] =~ /^(CPU|Processor)[\s_]Fan/i || 
		$row[$i_key] =~ /^SYS\.[0-9][\s_]?\(CPU\s?0\)$/i){
			$speed = int($row[$i_value]);
			$sensors->{'fan-main'}->[1] = $speed if $speed < $max_fan;
		}
		# note that the counters are dynamically set for fan numbers here
		# otherwise you could overwrite eg aux fan2 with case fan2 in theory
		# note: cpu/mobo/ps are 1/2/3
		# SYS.3(Front 2)
		# $row[$i_key] =~ /^(SYS[\.])([0-9])\s?\((Front|Rear).+\)$/i
		elsif ($row[$i_key] =~ /^(SYS[\s_])?FAN[\s_]?([0-9A-F]+)/i){
			$sys_fan_nu = hex($2);
			$fan_working = int($row[$i_value]);
			next if $fan_working > $max_fan;
			$sensors->{'fan-default'} = () if !$sensors->{'fan-default'};
			if ($sys_fan_nu =~ /^([0-9]+)$/){
				# add to array if array index does not exist OR if number is > existing number
				if (defined $sensors->{'fan-default'}->[$sys_fan_nu]){
					if ($fan_working >= $sensors->{'fan-default'}->[$sys_fan_nu]){
						$sensors->{'fan-default'}->[$sys_fan_nu] = $fan_working;
					}
				}
				else {
					$sensors->{'fan-default'}->[$sys_fan_nu] = $fan_working;
				}
			}
		}
		elsif ($row[$i_key] =~ /^(FAN PSU|PSU FAN)$/i){
			$speed = int($row[$i_value]);
			$sensors->{'fan-psu'} = $speed if $speed < $max_fan;
		}
		elsif ($row[$i_key] =~ /^(FAN PSU1|PSU1 FAN)$/i){
			$speed = int($row[$i_value]);
			$sensors->{'fan-psu-1'} = $speed if $speed < $max_fan;
		}
		elsif ($row[$i_key] =~ /^(FAN PSU2|PSU2 FAN)$/i){
			$speed = int($row[$i_value]);
			$sensors->{'fan-psu-2'} = $speed if $speed < $max_fan;
		}
		if ($extra > 0){
			if ($row[$i_key] =~ /^((.+\s|P[_]?)?\+?12V|PSU[12]_VOUT)$/i){
				$sensors->{'volts-12'} = $row[$i_value];
			}
			elsif ($row[$i_key] =~ /^(.+\s5V|P5V|5VCC|5V( PG)?|5V_SB)$/i){
				$sensors->{'volts-5'} = $row[$i_value];
			}
			elsif ($row[$i_key] =~ /^(.+\s3\.3V|P3V3|3\.3VCC|3\.3V( PG)?|3V3_SB)$/i){
				$sensors->{'volts-3.3'} = $row[$i_value];
			}
			elsif ($row[$i_key] =~ /^((P_)?VBAT|CMOS Battery|BATT 3.0V)$/i){
				$sensors->{'volts-vbat'} = $row[$i_value];
			}
			# NOTE: VDimmP1ABC VDimmP1DEF
			elsif (!$sensors->{'volts-dimm-p1'} && $row[$i_key] =~ /^(P1_VMEM|VDimmP1|MEM RSR A PG|DIMM_VR1_VOLT)/i){
				$sensors->{'volts-dimm-p1'} = $row[$i_value];
			}
			elsif (!$sensors->{'volts-dimm-p2'} && $row[$i_key] =~ /^(P2_VMEM|VDimmP2|MEM RSR B PG|DIMM_VR2_VOLT)/i){
				$sensors->{'volts-dimm-p2'} = $row[$i_value];
			}
			elsif (!$sensors->{'volts-soc-p1'} && $row[$i_key] =~ /^(P1_SOC_RUN$)/i){
				$sensors->{'volts-soc-p1'} = $row[$i_value];
			}
			elsif (!$sensors->{'volts-soc-p2'} && $row[$i_key] =~ /^(P2_SOC_RUN$)/i){
				$sensors->{'volts-soc-p2'} = $row[$i_value];
			}
		}
	}
	print Data::Dumper::Dumper $sensors if $dbg[31];
	process_data($sensors) if %$sensors;
	main::log_data('dump','ipmi: %$sensors',$sensors) if $b_log;
	eval $end if $b_log;
	print Data::Dumper::Dumper $sensors if $dbg[31];
	return $sensors;
}

sub linux_sensors_data {
	eval $start if $b_log;
	my $sensors = {};
	my ($sys_fan_nu)  = (0);
	my ($adapter,$fan_working,$temp_working,$working_unit)  = ('','','','','');
	foreach $adapter (keys %{$sensors_raw->{'main'}}){
		next if !$adapter || ref $sensors_raw->{'main'}{$adapter} ne 'ARRAY';
		# not sure why hwmon is excluded, forgot to add info in comments
		if ((@sensors_use && !(grep {/$adapter/} @sensors_use)) ||
		 (@sensors_exclude && (grep {/$adapter/} @sensors_exclude))){
			next;
		}
		foreach (@{$sensors_raw->{'main'}{$adapter}}){
			my @working = split(':', $_);
			next if !$working[0];
			# print "$working[0]:$working[1]\n";
			# There are some guesses here, but with more sensors samples it will get closer.
			# note: using arrays starting at 1 for all fan arrays to make it easier overall
			# we have to be sure we are working with the actual real string before assigning
			# data to real variables and arrays. Extracting C/F degree unit as well to use
			# when constructing temp items for array. 
			# note that because of charset issues, no "°" degree sign used, but it is required 
			# in testing regex to avoid error. It might be because I got that data from a forum post,
			# note directly via debugger.
			if ($_ =~ /^T?(AMBIENT|M\/B|MB|Motherboard|SIO|SYS).*:([0-9\.]+)[\s°]*(C|F)/i){
				# avoid SYSTIN: 118 C
				if (main::is_numeric($2) && $2 < 90){
					$sensors->{'mobo-temp'} = $2;
					$working_unit = $3;
					$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
				}
			}
			# issue 58 msi/asus show wrong for CPUTIN so overwrite it if PECI 0 is present
			# http://www.spinics.net/lists/lm-sensors/msg37308.html
			# NOTE: had: ^CPU.*\+([0-9]+): but that misses: CPUTIN and anything not with + in starter
			# However, "CPUTIN is not a reliable measurement because it measures difference to Tjmax,
			# which is the maximum CPU temperature reported as critical temperature by coretemp"
			# NOTE: I've seen an inexplicable case where: CPU:52.0°C fails to match with [\s°] but 
			# does match with: [\s°]*. I can't account for this, but that's why the * is there
			# Tdie is a new k10temp-pci syntax for real cpu die temp. Tctl is cpu control value, 
			# NOT the real cpu die temp: UNLESS tctl and tdie are equal, sigh..
			elsif ($_ =~ /^(Chip 0.*?|T?CPU.*|Tdie.*):([0-9\.]+)[\s°]*(C|F)/i){
				$temp_working = $2;
				$working_unit = $3;
				if (!$sensors->{'cpu-temp'} || 
				 (defined $temp_working && $temp_working > 0 && $temp_working > $sensors->{'cpu-temp'})){
					$sensors->{'cpu-temp'} = $temp_working;
				}
				$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
			}
			elsif ($_ =~ /^(Tctl.*):([0-9\.]+)[\s°]*(C|F)/i){
				$temp_working = $2;
				$working_unit = $3;
				if (!$sensors->{'tctl-temp'} || 
				 (defined $temp_working && $temp_working > 0 && $temp_working > $sensors->{'tctl-temp'})){
					$sensors->{'tctl-temp'} = $temp_working;
				}
				$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
			}
			elsif ($_ =~ /^PECI\sAgent\s0.*:([0-9\.]+)[\s°]*(C|F)/i){
				$sensors->{'cpu-peci-temp'} = $1;
				$working_unit = $2;
				$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
			}
			elsif ($_ =~ /^T?(P\/S|Power).*:([0-9\.]+)[\s°]*(C|F)/i){
				$sensors->{'psu-temp'} = $2;
				$working_unit = $3;
				$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
			}
			elsif ($_ =~ /^T?(dimm|mem|sodimm).*?:([0-9\.]+)[\s°]*(C|F)/i){
				$sensors->{'sodimm-temp'} = $1;
				$working_unit = $2;
				$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
			}
			# for temp1/2 only use temp1/2 if they are null or greater than the last ones
			elsif ($_ =~ /^temp1:([0-9\.]+)[\s°]*(C|F)/i){
				$temp_working = $1;
				$working_unit = $2;
				if (!$sensors->{'temp1'} || 
				 (defined $temp_working && $temp_working > 0 && $temp_working > $sensors->{'temp1'})){
					$sensors->{'temp1'} = $temp_working;
				}
				$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
			}
			elsif ($_ =~ /^temp2:([0-9\.]+)[\s°]*(C|F)/i){
				$temp_working = $1;
				$working_unit = $2;
				if (!$sensors->{'temp2'} || 
				 (defined $temp_working && $temp_working > 0 && $temp_working > $sensors->{'temp2'})){
					$sensors->{'temp2'} = $temp_working;
				}
				$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
			}
			# temp3 is only used as an absolute override for systems with all 3 present
			elsif ($_ =~ /^temp3:([0-9\.]+)[\s°]*(C|F)/i){
				$temp_working = $1;
				$working_unit = $2;
				if (!$sensors->{'temp3'} || 
				 (defined $temp_working && $temp_working > 0 && $temp_working > $sensors->{'temp3'})){
					$sensors->{'temp3'} = $temp_working;
				}
				$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
			}
			# final fallback if all else fails, funtoo user showed sensors putting
			# temp on wrapped second line, not handled
			elsif ($_ =~ /^T?(core0|core 0|Physical id 0)(.*):([0-9\.]+)[\s°]*(C|F)/i){
				$temp_working = $3;
				$working_unit = $4;
				if (!$sensors->{'core-0-temp'} || 
				 (defined $temp_working && $temp_working > 0 && $temp_working > $sensors->{'core-0-temp'})){
					$sensors->{'core-0-temp'} = $temp_working;
				}
				$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit) if $working_unit;
			}
			# note: can be cpu fan:, cpu fan speed:, etc.
			elsif (!defined $sensors->{'fan-main'}->[1] && $_ =~ /^F?(CPU|Processor).*:([0-9]+)[\s]RPM/i){
				$sensors->{'fan-main'}->[1] = $2 if $2 < $max_fan;
			}
			elsif (!defined $sensors->{'fan-main'}->[2] && $_ =~ /^F?(M\/B|MB|SYS|Motherboard).*:([0-9]+)[\s]RPM/i){
				$sensors->{'fan-main'}->[2] = $2 if $2 < $max_fan;
			}
			elsif (!defined $sensors->{'fan-main'}->[3] && $_ =~ /F?(Power|P\/S|POWER).*:([0-9]+)[\s]RPM/i){
				$sensors->{'fan-main'}->[3] = $2 if $2 < $max_fan;
			}
			elsif (!defined $sensors->{'fan-main'}->[4] && $_ =~ /F?(dimm|mem|sodimm).*:([0-9]+)[\s]RPM/i){
				$sensors->{'fan-main'}->[4] = $2 if $2 < $max_fan;
			}
			# note that the counters are dynamically set for fan numbers here
			# otherwise you could overwrite eg aux fan2 with case fan2 in theory
			# note: cpu/mobo/ps/sodimm are 1/2/3/4
			elsif ($_ =~ /^F?(AUX|CASE|CHASSIS|FRONT|REAR).*:([0-9]+)[\s]RPM/i){
				next if $2 > $max_fan;
				$temp_working = $2;
				for (my $i = 5; $i < 30; $i++){
					next if defined $sensors->{'fan-main'}->[$i];
					if (!defined $sensors->{'fan-main'}->[$i]){
						$sensors->{'fan-main'}->[$i] = $temp_working;
						last;
					}
				}
			}
			# in rare cases syntax is like: fan1: xxx RPM
			elsif ($_ =~ /^FAN(1)?:([0-9]+)[\s]RPM/i){
				$sensors->{'fan-default'}->[1] = $2 if $2 < $max_fan;
			}
			elsif ($_ =~ /^FAN([2-9]|1[0-9]).*:([0-9]+)[\s]RPM/i){
				next if $2 > $max_fan;
				$fan_working = $2;
				$sys_fan_nu = $1;
				if ($sys_fan_nu =~ /^([0-9]+)$/){
					# add to array if array index does not exist OR if number is > existing number
					if (defined $sensors->{'fan-default'}->[$sys_fan_nu]){
						if ($fan_working >= $sensors->{'fan-default'}->[$sys_fan_nu]){
							$sensors->{'fan-default'}->[$sys_fan_nu] = $fan_working;
						}
					}
					else {
						$sensors->{'fan-default'}->[$sys_fan_nu] = $fan_working;
					}
				}
			}
			if ($extra > 0){
				if ($_ =~ /^[+]?(12 Volt|12V|V\+?12).*:([0-9\.]+)\sV/i){
					$sensors->{'volts-12'} = $2;
				}
				# note: 5VSB is a field name
				elsif ($_ =~ /^[+]?(5 Volt|5V|V\+?5):([0-9\.]+)\sV/i){
					$sensors->{'volts-5'} = $2;
				}
				elsif ($_ =~ /^[+]?(3\.3 Volt|3\.3V|V\+?3\.3).*:([0-9\.]+)\sV/i){
					$sensors->{'volts-3.3'} = $2;
				}
				elsif ($_ =~ /^(Vbat).*:([0-9\.]+)\sV/i){
					$sensors->{'volts-vbat'} = $2;
				}
				elsif ($_ =~ /^v(dimm|mem|sodimm).*:([0-9\.]+)\sV/i){
					$sensors->{'volts-mem'} = $2;
				}
			}
		}
	}
	foreach $adapter (keys %{$sensors_raw->{'pch'}}){
		next if !$adapter || ref $sensors_raw->{'pch'}{$adapter} ne 'ARRAY';
		if ((@sensors_use && !(grep {/$adapter/} @sensors_use)) ||
		 (@sensors_exclude && (grep {/$adapter/} @sensors_exclude))){
			next;
		}
		$temp_working = '';
		foreach (@{$sensors_raw->{'pch'}{$adapter}}){
			if ($_ =~ /^[^:]+:([0-9\.]+)[\s°]*(C|F)/i){
				$temp_working = $1;
				$working_unit = $2;
				if (!$sensors->{'pch-temp'} || 
				 (defined $temp_working && $temp_working > 0 && $temp_working > $sensors->{'pch-temp'})){
					$sensors->{'pch-temp'} = $temp_working;
				}
				if (!$sensors->{'temp-unit'} && $working_unit){
					$sensors->{'temp-unit'} = set_temp_unit($sensors->{'temp-unit'},$working_unit);
				}
			}
		}
	}
	print Data::Dumper::Dumper $sensors if $dbg[31];
	process_data($sensors) if %$sensors;
	main::log_data('dump','lm-sensors: %sensors',$sensors) if $b_log;
	print Data::Dumper::Dumper $sensors if $dbg[31];
	eval $end if $b_log;
	return $sensors;
}

sub load_lm_sensors {
	eval $start if $b_log;
	my (@sensors_data,@values);
	my ($adapter,$holder,$type) = ('','','');
		if ($fake{'sensors'}){
		# my $file;
		# $file = "$fake_data_dir/sensors/lm-sensors/amdgpu-w-fan-speed-stretch-k10.txt";
		# $file = "$fake_data_dir/sensors/lm-sensors/peci-tin-geggo.txt";
		# $file = "$fake_data_dir/sensors/lm-sensors/sensors-w-other-biker.txt";
		# $file = "$fake_data_dir/sensors/lm-sensors/sensors-asus-chassis-1.txt";
		# $file = "$fake_data_dir/sensors/lm-sensors/sensors-devnull-1.txt";
		# $file = "$fake_data_dir/sensors/lm-sensors/sensors-jammin1.txt";
		# $file = "$fake_data_dir/sensors/lm-sensors/sensors-mx-incorrect-1.txt";
		# $file = "$fake_data_dir/sensors/lm-sensors/sensors-maximus-arch-1.txt";
		# $file = "$fake_data_dir/sensors/lm-sensors/kernel-58-sensors-ant-1.txt";
		# $file = "$fake_data_dir/sensors/lm-sensors/sensors-zenpower-nvme-2.txt";
		# $file = "$fake_data_dir/sensors/lm-sensors/sensors-pch-intel-1.txt";
		# $file = "$fake_data_dir/sensors/slm-sensors/ensors-ppc-sr71.txt";
		# $file = "$fake_data_dir/sensors/lm-sensors/sensors-coretemp-acpitz-1.txt";
		# $file = "$fake_data_dir/sensors/lm-sensors/sensors-applesmc-1.txt";
		# @sensors_data = main::reader($file);
	}
	else {
		# only way to get sensor array data? Unless using sensors -j, but can't assume json 
		@sensors_data = main::grabber($alerts{'sensors'}->{'path'} . ' 2>/dev/null');
	}
	# print join("\n", @sensors_data), "\n";
	if (@sensors_data){
		@sensors_data = map {$_ =~ s/\s*:\s*\+?/:/;$_} @sensors_data;
		push(@sensors_data, 'END');
	}
	# print Data::Dumper::Dumper \@sensors_data;
	foreach (@sensors_data){
		# print 'st:', $_, "\n";
		next if /^\s*$/;
		$_ = main::trimmer($_);
		if (@values && $adapter && (/^Adapter/ || $_ eq 'END')){
			# note: drivetemp: known, but many others could exist
			if ($adapter =~ /^(drive|nvme)/){
				$type = 'disk';
			}
			elsif ($adapter =~ /^(BAT)/){
				$type = 'bat';
			}
			# intel on die io controller, like southbridge/northbridge used to be
			elsif ($adapter =~ /^(pch[_-])/){
				$type = 'pch';
			}
			elsif ($adapter =~ /^(.*hwmon)-/){
				$type = 'hwmon';
			}
			# ath/iwl: wifi; enp/eno/eth/i350bb: lan nic
			elsif ($adapter =~ /^(ath|i350bb|iwl|en[op][0-9]|eth)[\S]+-/){
				$type = 'network';
			}
			# put last just in case some other sensor type above had intel in name
			elsif ($adapter =~ /^(amdgpu|intel|nova|nouveau|radeon)-/){
				$type = 'gpu';
			}
			elsif ($adapter =~ /^(acpitz)-/ && $adapter !~ /^(acpitz-virtual)-/ ){
				$type = 'acpitz';
			}
			else {
				$type = 'main';
			}
			$sensors_raw->{$type}{$adapter} = [@values];
			@values = ();
			$adapter = '';
		}
		if (/^Adapter/){
			$adapter = $holder;
		}
		elsif (/\S:\S/){
			push(@values, $_);
		}
		else {
			$holder = $_;
		}
	}
	print 'lm sensors: ' , Data::Dumper::Dumper $sensors_raw if $dbg[18];
	main::log_data('dump','lm-sensors data: %$sensors_raw',$sensors_raw) if $b_log;
	eval $end if $b_log;
}

sub load_sys_data {
	eval $start if $b_log;
	my ($device,$mon,$name,$label,$unit,$value,@values,%hwmons);
	my ($j,$holder,$sensor,$type) = (0,'','','');
	my $glob = '/sys/class/hwmon/hwmon*/';
	$glob .= '{name,device,{curr,fan,in,power,temp}*_{input,label}}';
	my @hwmon = main::globber($glob);
	# print Data::Dumper::Dumper \@sensors_data;
	@hwmon = sort @hwmon;
	push(@hwmon,'END');
	foreach my $item (@hwmon){
		next if ! -e $item;
		$item =~ m|/sys/class/hwmon/(hwmon\d+)/|;
		$mon = $1;
		$mon =~ s/hwmon(\d)$/hwmon0$1/ if $mon =~ /hwmon\d$/;
		# if it's a new hwmon, dump all previous data to avoid carry-over
		if (!defined $hwmons{$mon}){
			$sensor = '';
			$holder = '';
			$j = 0;
		}
		if ($item =~ m/([^\/]+)_input$/){
			$sensor = $1;
			$value = main::reader($item,'strip',0);;
		}
		# add the label to the just created _input item, if valid
		elsif ($item =~ m/([^\/]+)_label$/){
			print "3: mon: $mon id: $sensor holder: $holder file: $item\n" if $dbg[51];
			# if this doesn't match, something unexpected happened, like no _input for
			# _label item. Seen that, real.
			next if !$holder || $1 ne $holder;
			if (defined $hwmons{$mon}->{'sensors'}[$j]{'id'}){
				$sensor = $1;
				$hwmons{$mon}->{'sensors'}[$j]{'label'} = main::reader($item,'strip',0);
			}
		}
		if ($sensor && ($sensor ne $holder || $item eq 'END')){
			print "2: mon: $mon id: $sensor holder: $holder file: $item\n" if $dbg[51];
			# add the item, we'll add label after if it's located since it will be next 
			# in loop due to sort order.
			if ($value){
				push(@{$hwmons{$mon}->{'sensors'}},{
				'id' => $sensor,
				'value' => $value,
				});
				$j = $#{$hwmons{$mon}->{'sensors'}};
			}
			$holder = $sensor;
			($sensor,$value) = ('',undef,undef);
		}
		print "1: mon: $mon id: $sensor holder: $holder file: $item\n" if $dbg[51];
		# print "$item\n";
		if ($item =~ /name$/){
			$name = main::reader($item,'strip',0);
			if ($name =~ /^(drive|nvme)/){
				$type = 'disk';
			}
			elsif ($name =~ /^(BAT)/i){
				$type = 'bat';
			}
			# intel on die io controller, like southbridge/northbridge used to be
			elsif ($name =~ /^(pch)/){
				$type = 'pch';
			}
			elsif ($name =~ /^(.*hwmon)/){
				$type = 'hwmon';
			}
			# ath/iwl: wifi; enp/eno/eth/i350bb: lan nic
			elsif ($name =~ /^(ath|i350|iwl|en[op][0-9]|eth)[\S]/){
				$type = 'network';
			}
			# put last just in case some other sensor type above had intel in name
			elsif ($name =~ /^(amdgpu|intel|nova|nouveau|radeon)/){
				$type = 'gpu';
			}
			# not confirmed in /sys that name will be acpitz-virtual, verify
			elsif ($name =~ /^(acpitz)/ && $name !~ /^(acpitz-virtual)/ ){
				$type = 'acpitz';
			}
			else {
				$type = 'main';
			}
			$hwmons{$mon}->{'name'} = $name;
			$hwmons{$mon}->{'type'} = $type;
		}
		elsif ($item =~ /device$/){
			$device = readlink($item);
			print "device: $device\n" if $dbg[51];
			$device =~ s|^.*/||;
			$hwmons{$mon}->{'device'} = $device;
		}
	}
	print '/sys/class/hwmon raw: ', Data::Dumper::Dumper \%hwmons if $dbg[18];
	main::log_data('dump','/sys data raw: %hwmons',\%hwmons) if $b_log;
	# $sensors_raw->{$type}{$adapter} = [@values];
	foreach my $hwmon (sort keys %hwmons){
		my $adapter = $hwmons{$hwmon}->{'name'};
		$hwmons{$hwmon}->{'device'} =~ s/^0000://;
		$adapter .= '-' . $hwmons{$hwmon}->{'device'};
		($unit,$value,@values) = ();
		foreach my $item (@{$hwmons{$hwmon}->{'sensors'}}){
			next if !defined $item->{'id'};
			my $name = ($item->{'label'}) ? $item->{'label'}: $item->{'id'};
			if ($item->{'id'} =~ /^temp/){
				$unit = 'C';
				$value = sprintf('%0.1f',$item->{'value'}/1000);
			}
			elsif ($item->{'id'} =~ /^fan/){
				$unit = 'rpm';
				$value = $item->{'value'};
			}
			# note: many sensors require further math on value, so these will be wrong
			# in many cases since this is not running the math on the results like 
			# lm-sensors will do if sensors are detected and loaded and configured.
			elsif ($item->{'id'} =~ /^in\d/){
				if ($item->{'value'} >= 1000){
					$unit = 'V';
					$value = sprintf('%0.2f',$item->{'value'}/1000) + 0;
					if ($hwmons{$hwmon}->{'type'} eq 'main' && $name =~ /^in\d/){
						if ($value >= 10 && $value <= 14){
							$name = '12V';
						}
						elsif ($value >= 4 && $value <= 6){
							$name = '5V';
						}
						# vbat can be 3, 3.3, but so can 3.3V board
					}
				}
				else {
					$unit = 'mV';
					$value = $item->{'value'};
				}
			}
			elsif ($item->{'id'} =~ /^power/){
				$unit = 'W';
				$value = sprintf('%0.1f',$item->{'value'}/1000);
			}
			if (defined $value && defined $unit){
				my $string = $name . ':' . $value . " $unit";
				push(@values,$string);
			}
		}
		#	if ($hwmons{$hwmon}->{'type'} eq 'acpitz' && $hwmons{$hwmon}->{'device'}){
		#		my $tz ='/sys/class/thermal/' . $hwmons{$hwmon}->{'device'} . '/type';
		#		if (-e $tz){
		#			my $tz_type = main::reader($tz,'strip',0),"\n";
		#		}
		#	}
		if (@values){
			$sensors_raw->{$hwmons{$hwmon}->{'type'}}{$adapter} = [@values];
		}
	}
	print '/sys/class/hwmon processed: ' , Data::Dumper::Dumper $sensors_raw if $dbg[18];
	main::log_data('dump','/sys data: %$sensors_raw',$sensors_raw) if $b_log;
	eval $end if $b_log;
}

# bsds sysctl may have hw.sensors data
sub sysctl_data {
	eval $start if $b_log;
	my (@data);
	my $sensors = {};
	# assume always starts at 0, can't do dynamic because freebsd shows tz1 first
	my $add = 1; 
	print Data::Dumper::Dumper $sysctl{'sensor'} if $dbg[18];;
	foreach (@{$sysctl{'sensor'}}){
		my ($sensor,$type,$number,$value);
		if (/^hw\.sensors\.([a-z]+)([0-9]+)\.(cpu|temp|fan|volt)([0-9])/){
			$sensor = $1;
			$type = $3;
			$number = $4;
			# hw.sensors.cpu0.temp0:47.00 degC
			# hw.sensors.acpitz0.temp0:43.00 degC
			$type = 'cpu' if $sensor eq 'cpu';
		}
		elsif (/^hw\.sensors\.(acpi)\.(thermal)\.(tz)([0-9]+)\.(temperature)/){
			$sensor = $1 . $3; # eg acpitz
			$type = ($5 eq 'temperature') ? 'temp': $5;
			$number = $4;
		}
		elsif (/^dev\.(cpu)\.([0-9]+)\.(temperature)/){
			$sensor = $1;
			$type = $3;
			$number = $2;
			$type = 'cpu' if $sensor eq 'cpu';
		}
		if ($sensor && $type){
			if ($sensor && ((@sensors_use && !(grep {/$sensor/} @sensors_use)) ||
			 (@sensors_exclude && (grep {/$sensor/} @sensors_exclude)))){
				next;
			}
			my $working = (split(':\s*', $_))[1];
			if (defined $working && $working =~ /^([0-9\.]+)\s?((deg)?([CF]))?\b/){
				 $value = $1 ;
				 $sensors->{'temp-unit'} = $4 if $4 && !$sensors->{'temp-unit'};
			}
			else {
				next;
			}
			$number += $add;
			if ($type eq 'cpu' && !defined $sensors->{'cpu-temp'}){
				$sensors->{'cpu-temp'} = $value;
			}
			elsif ($type eq 'temp' && !defined $sensors->{'temp' . $number}){
				$sensors->{'temp' . $number} = $value;
			}
			elsif ($type eq 'fan' && !defined $sensors->{'fan-main'}->[$number]){
				$sensors->{'fan-main'}->[$number] = $value if  $value < $max_fan;
			}
			elsif ($type eq 'volt'){
				if ($working =~ /\+3\.3V/i){
					$sensors->{'volts-3.3'} = $value;
				}
				elsif ($working =~ /\+5V/i){
					$sensors->{'volts-5'} = $value;
				}
				elsif ($working =~ /\+12V/i){
					$sensors->{'volts-12'} = $value;
				}
				elsif ($working =~ /VBAT/i){
					$sensors->{'volts-vbat'} = $value;
				}
			}
		}
	}
	process_data($sensors) if %$sensors;
	main::log_data('dump','%$sensors',$sensors) if $b_log;
	print Data::Dumper::Dumper $sensors if $dbg[31];;
	eval $end if $b_log;
	return $sensors;
}

sub set_temp_unit {
	my ($sensors,$working) = @_;
	my $return_unit = '';
	if (!$sensors && $working){
		$return_unit = $working;
	}
	elsif ($sensors){
		$return_unit = $sensors;
	}
	return $return_unit;
}

sub process_data {
	eval $start if $b_log;
	my ($sensors) = @_;
	my ($cpu_temp,$cpu2_temp,$cpu3_temp,$cpu4_temp,$mobo_temp,$pch_temp,$psu_temp);
	my ($fan_type,$i,$j,$index_count_fan_default,$index_count_fan_main) = (0,0,0,0,0);
	my $temp_diff = 20; # for C, handled for F after that is determined
	my (@fan_main,@fan_default);
	# kernel/sensors only show Tctl if Tctl == Tdie temp, sigh...
	if (!$sensors->{'cpu-temp'} && $sensors->{'tctl-temp'}){
		$sensors->{'cpu-temp'} = $sensors->{'tctl-temp'};
		undef $sensors->{'tctl-temp'};
	}
	# first we need to handle the case where we have to determine which temp/fan to use for cpu and mobo:
	# note, for rare cases of weird cool cpus, user can override in their prefs and force the assignment
	# this is wrong for systems with > 2 tempX readings, but the logic is too complex with 3 variables
	# so have to accept that it will be wrong in some cases, particularly for motherboard temp readings.
	if ($sensors->{'temp1'} && $sensors->{'temp2'}){
		if ($sensors_cpu_nu){
			$fan_type = $sensors_cpu_nu;
		}
		else {
			# first some fringe cases with cooler cpu than mobo: assume which is cpu temp based on fan speed
			# but only if other fan speed is 0.
			if ($sensors->{'temp1'} >= $sensors->{'temp2'} && 
			 defined $fan_default[1] && defined $fan_default[2] && $fan_default[1] == 0 && $fan_default[2] > 0){
				$fan_type = 2;
			}
			elsif ($sensors->{'temp2'} >= $sensors->{'temp1'} && 
			 defined $fan_default[1] && defined $fan_default[2] && $fan_default[2] == 0 && $fan_default[1] > 0){
				$fan_type = 1;
			}
			# then handle the standard case if these fringe cases are false
			elsif ($sensors->{'temp1'} >= $sensors->{'temp2'}){
				$fan_type = 1;
			}
			else {
				$fan_type = 2;
			}
		}
	}
	# need a case for no temps at all reported, like with old intels
	elsif (!$sensors->{'temp2'} && !$sensors->{'cpu-temp'}){
		if (!$sensors->{'temp1'} && !$sensors->{'mobo-temp'}){
			$fan_type = 1;
		}
		elsif ($sensors->{'temp1'} && !$sensors->{'mobo-temp'}){
			$fan_type = 1;
		}
		elsif ($sensors->{'temp1'} && $sensors->{'mobo-temp'}){
			$fan_type = 1;
		}
	}
	# convert the diff number for F, it needs to be bigger that is
	if ($sensors->{'temp-unit'} && $sensors->{'temp-unit'} eq "F"){
		$temp_diff = $temp_diff * 1.8
	}
	if ($sensors->{'cpu-temp'}){
		# specific hack to handle broken CPUTIN temps with PECI
		if ($sensors->{'cpu-peci-temp'} && ($sensors->{'cpu-temp'} - $sensors->{'cpu-peci-temp'}) > $temp_diff){
			$cpu_temp = $sensors->{'cpu-peci-temp'};
		}
		# then get the real cpu temp, best guess is hottest is real, though only within narrowed diff range
		else {
			$cpu_temp = $sensors->{'cpu-temp'};
		}
	}
	else {
		if ($fan_type){
			# there are some weird scenarios
			if ($fan_type == 1){
				if ($sensors->{'temp1'} && $sensors->{'temp2'} && $sensors->{'temp2'} > $sensors->{'temp1'}){
					$cpu_temp = $sensors->{'temp2'};
				}
				else {
					$cpu_temp = $sensors->{'temp1'};
				}
			}
			else {
				if ($sensors->{'temp1'} && $sensors->{'temp2'} && $sensors->{'temp1'} > $sensors->{'temp2'}){
					$cpu_temp = $sensors->{'temp1'};
				}
				else {
					$cpu_temp = $sensors->{'temp2'};
				}
			}
		}
		else {
			$cpu_temp = $sensors->{'temp1'}; # can be null, that is ok
		}
		if ($cpu_temp){
			# using $sensors->{'temp3'} is just not reliable enough, more errors caused than fixed imo
			# if ($sensors->{'temp3'} && $sensors->{'temp3'} > $cpu_temp){
			#	$cpu_temp = $sensors->{'temp3'};
			# }
			# there are some absurdly wrong $sensors->{'temp1'}: acpitz-virtual-0 $sensors->{'temp1'}: +13.8°C
			if ($sensors->{'core-0-temp'} && ($sensors->{'core-0-temp'} - $cpu_temp) > $temp_diff){
				$cpu_temp = $sensors->{'core-0-temp'};
			}
		}
	}
	# if all else fails, use core0/peci temp if present and cpu is null
	if (!$cpu_temp){
		if ($sensors->{'core-0-temp'}){
			$cpu_temp = $sensors->{'core-0-temp'};
		}
		# note that peci temp is known to be colder than the actual system
		# sometimes so it is the last fallback we want to use even though in theory
		# it is more accurate, but fact suggests theory wrong.
		elsif ($sensors->{'cpu-peci-temp'}){
			$cpu_temp = $sensors->{'cpu-peci-temp'};
		}
	}
	# then the real mobo temp
	if ($sensors->{'mobo-temp'}){
		$mobo_temp = $sensors->{'mobo-temp'};
	}
	elsif ($fan_type){
		if ($fan_type == 1){
			if ($sensors->{'temp1'} && $sensors->{'temp2'} && $sensors->{'temp2'} > $sensors->{'temp1'}){
				$mobo_temp = $sensors->{'temp1'};
			}
			else {
				$mobo_temp = $sensors->{'temp2'};
			}
		}
		else {
			if ($sensors->{'temp1'} && $sensors->{'temp2'} && $sensors->{'temp1'} > $sensors->{'temp2'}){
				$mobo_temp = $sensors->{'temp2'};
			}
			else {
				$mobo_temp = $sensors->{'temp1'};
			}
		}
		## NOTE: not safe to assume $sensors->{'temp3'} is the mobo temp, sad to say
		# if ($sensors->{'temp1'} && $sensors->{'temp2'} && $sensors->{'temp3'} && $sensors->{'temp3'} < $mobo_temp){
		#		$mobo_temp = $sensors->{'temp3'};
		# }
	}
	# in case with cpu-temp AND temp1 and not temp 2, or temp 2 only, fan type: 0
	else {
		if ($sensors->{'cpu-temp'} && $sensors->{'temp1'} && 
		 $sensors->{'cpu-temp'} > $sensors->{'temp1'}){
			$mobo_temp = $sensors->{'temp1'};
		}
		elsif ($sensors->{'temp2'}){
			$mobo_temp = $sensors->{'temp2'};
		}
	}
	@fan_main = @{$sensors->{'fan-main'}} if $sensors->{'fan-main'};
	$index_count_fan_main = (@fan_main) ? scalar @fan_main : 0;
	@fan_default = @{$sensors->{'fan-default'}} if $sensors->{'fan-default'};
	$index_count_fan_default = (@fan_default) ? scalar @fan_default : 0;
	# then set the cpu fan speed
	if (!$fan_main[1]){
		# note, you cannot test for $fan_default[1] or [2] != "" 
		# because that creates an array item in gawk just by the test itself
		if ($fan_type == 1 && defined $fan_default[1]){
			$fan_main[1] = $fan_default[1];
			$fan_default[1] = undef;
		}
		elsif ($fan_type == 2 && defined $fan_default[2]){
			$fan_main[1] = $fan_default[2];
			$fan_default[2] = undef;
		}
	}
	# clear out any duplicates. Primary fan real trumps fan working always if same speed
	for ($i = 1; $i <= $index_count_fan_main; $i++){
		if (defined $fan_main[$i] && $fan_main[$i]){
			for ($j = 1; $j <= $index_count_fan_default; $j++){
				if (defined $fan_default[$j] && $fan_main[$i] == $fan_default[$j]){
					$fan_default[$j] = undef;
				}
			}
		}
	}
	# now see if you can find the fast little mobo fan, > 5000 rpm and put it as mobo
	# note that gawk is returning true for some test cases when $fan_default[j] < 5000
	# which has to be a gawk bug, unless there is something really weird with arrays
	# note: 500 > $fan_default[j] < 1000 is the exact trigger, and if you manually 
	# assign that value below, the > 5000 test works again, and a print of the value
	# shows the proper value, so the corruption might be internal in awk. 
	# Note: gensub is the culprit I think, assigning type string for range 501-1000 but 
	# type integer for all others, this triggers true for >
	for ($j = 1; $j <= $index_count_fan_default; $j++){
		if (defined $fan_default[$j] && $fan_default[$j] > 5000 && !$fan_main[2]){
			$fan_main[2] = $fan_default[$j];
			$fan_default[$j] = undef;
			# then add one if required for output
			if ($index_count_fan_main < 2){
				$index_count_fan_main = 2;
			}
		}
	}
	# if they are ALL null, print error message. psFan is not used in output currently
	if (!$cpu_temp && !$mobo_temp && !$fan_main[1] && !$fan_main[2] && !$fan_main[1] && !@fan_default){
		%$sensors = ();
	}
	else {
		my ($ambient_temp,$psu_fan,$psu1_fan,$psu2_fan,$psu_temp,$sodimm_temp,
		$v_12,$v_5,$v_3_3,$v_dimm_p1,$v_dimm_p2,$v_soc_p1,$v_soc_p2,$v_vbat);
		$psu_temp = $sensors->{'psu-temp'} if $sensors->{'psu-temp'};
		# sodimm fan is fan_main[4]
		$sodimm_temp = $sensors->{'sodimm-temp'} if $sensors->{'sodimm-temp'};
		$cpu2_temp = $sensors->{'cpu2-temp'} if $sensors->{'cpu2-temp'};
		$cpu3_temp = $sensors->{'cpu3-temp'} if $sensors->{'cpu3-temp'};
		$cpu4_temp = $sensors->{'cpu4-temp'} if $sensors->{'cpu4-temp'};
		$ambient_temp = $sensors->{'ambient-temp'} if $sensors->{'ambient-temp'};
		$pch_temp = $sensors->{'pch-temp'} if $sensors->{'pch-temp'};
		$psu_fan = $sensors->{'fan-psu'} if $sensors->{'fan-psu'};
		$psu1_fan = $sensors->{'fan-psu-1'} if $sensors->{'fan-psu-1'};
		$psu2_fan = $sensors->{'fan-psu-2'} if $sensors->{'fan-psu-2'};
		# so far only for ipmi, sensors data is junk for volts
		if ($extra > 0 && ($sensors->{'volts-12'} || $sensors->{'volts-5'} || 
		 $sensors->{'volts-3.3'} || $sensors->{'volts-vbat'})){
			$v_12 = $sensors->{'volts-12'} if $sensors->{'volts-12'};
			$v_5 = $sensors->{'volts-5'} if $sensors->{'volts-5'};
			$v_3_3 = $sensors->{'volts-3.3'} if  $sensors->{'volts-3.3'};
			$v_vbat = $sensors->{'volts-vbat'} if $sensors->{'volts-vbat'};
			$v_dimm_p1 = $sensors->{'volts-dimm-p1'} if $sensors->{'volts-dimm-p1'};
			$v_dimm_p2 = $sensors->{'volts-dimm-p2'} if $sensors->{'volts-dimm-p2'};
			$v_soc_p1 = $sensors->{'volts-soc-p1'} if $sensors->{'volts-soc-p1'};
			$v_soc_p2 = $sensors->{'volts-soc-p2'} if $sensors->{'volts-soc-p2'};
		}
		%$sensors = (
		'ambient-temp' => $ambient_temp,
		'cpu-temp' => $cpu_temp,
		'cpu2-temp' => $cpu2_temp,
		'cpu3-temp' => $cpu3_temp,
		'cpu4-temp' => $cpu4_temp,
		'mobo-temp' => $mobo_temp,
		'pch-temp' => $pch_temp,
		'psu-temp' => $psu_temp,
		'temp-unit' => $sensors->{'temp-unit'},
		'fan-main' => \@fan_main,
		'fan-default' => \@fan_default,
		'fan-psu' => $psu_fan,
		'fan-psu1' => $psu1_fan,
		'fan-psu2' => $psu2_fan,
		);
		if ($psu_temp){
			$sensors->{'psu-temp'} = $psu_temp;
		}
		if ($sodimm_temp){
			$sensors->{'sodimm-temp'} = $sodimm_temp;
		}
		if ($extra > 0 && ($v_12 || $v_5 || $v_3_3 || $v_vbat)){
			$sensors->{'volts-12'} = $v_12;
			$sensors->{'volts-5'} = $v_5;
			$sensors->{'volts-3.3'} = $v_3_3;
			$sensors->{'volts-vbat'} = $v_vbat;
			$sensors->{'volts-dimm-p1'} = $v_dimm_p1;
			$sensors->{'volts-dimm-p2'} = $v_dimm_p2;
			$sensors->{'volts-soc-p1'} = $v_soc_p1;
			$sensors->{'volts-soc-p2'} = $v_soc_p2;
		}
	}
	eval $end if $b_log;
}

sub gpu_sensor_data {
	eval $start if $b_log;
	my ($cmd,@data,@data2,$path,@screens,$temp);
	my $j = 0;
	$loaded{'gpu-data'} = 1;
	if ($path = main::check_program('nvidia-settings')){
		# first get the number of screens. This only work if you are in X
		if ($b_display){
			@data = main::grabber("$path -q screens 2>/dev/null");
			foreach (@data){
				if (/(:[0-9]\.[0-9])/){
					push(@screens, $1);
				}
			}
		}
		# do a guess, this will work for most users, it's better than nothing for out of X
		else {
			$screens[0] = ':0.0';
		}
		# now we'll get the gpu temp for each screen discovered. The print out function
		# will handle removing screen data for single gpu systems. -t shows only data we want
		# GPUCurrentClockFreqs: 520,600
		# GPUCurrentFanSpeed: 50 0-100, not rpm, percent I think
		# VideoRam: 1048576
		# CUDACores: 16 
		# PCIECurrentLinkWidth: 16
		# PCIECurrentLinkSpeed: 5000
		# RefreshRate: 60.02 Hz [oer screen]
		# ViewPortOut=1280x1024+0+0}, DPY-1: nvidia-auto-select @1280x1024 +1280+0 {ViewPortIn=1280x1024,
		# ViewPortOut=1280x1024+0+0}
		# ThermalSensorReading: 50
		# PCIID: 4318,2661 - the pci stuff doesn't appear to work
		# PCIBus: 2
		# PCIDevice: 0
		# Irq: 30
		foreach my $screen (@screens){
			my $screen2 = $screen;
			$screen2 =~ s/\.[0-9]$//;
			$cmd = '-q GPUCoreTemp -q VideoRam -q GPUCurrentClockFreqs -q PCIECurrentLinkWidth ';
			$cmd .= '-q Irq -q PCIBus -q PCIDevice -q GPUCurrentFanSpeed';
			$cmd = "$path -c $screen2 $cmd 2>/dev/null";
			@data = main::grabber($cmd);
			main::log_data('cmd',$cmd) if $b_log;
			push(@data,@data2);
			$j = scalar @$gpu_data;
			foreach my $item (@data){
				if ($item =~ /^\s*Attribute\s\'([^']+)\'\s.*:\s*([\S]+)\.$/){
					my $attribute = $1;
					my $value = $2;
					$gpu_data->[$j]{'type'} = 'nvidia';
					$gpu_data->[$j]{'speed-unit'} = '%';
					$gpu_data->[$j]{'screen'} = $screen;
					if (!$gpu_data->[$j]{'temp'} && $attribute eq 'GPUCoreTemp'){
						$gpu_data->[$j]{'temp'} = $value;
					}
					elsif (!$gpu_data->[$j]{'ram'} && $attribute eq 'VideoRam'){
						$gpu_data->[$j]{'ram'} = $value;
					}
					elsif (!$gpu_data->[$j]{'clock'} && $attribute eq 'GPUCurrentClockFreqs'){
						$gpu_data->[$j]{'clock'} = $value;
					}
					elsif (!$gpu_data->[$j]{'bus'} && $attribute eq 'PCIBus'){
						$gpu_data->[$j]{'bus'} = $value;
					}
					elsif (!$gpu_data->[$j]{'bus-id'} && $attribute eq 'PCIDevice'){
						$gpu_data->[$j]{'bus-id'} = $value;
					}
					elsif (!$gpu_data->[$j]{'fan-speed'} && $attribute eq 'GPUCurrentFanSpeed'){
						$gpu_data->[$j]{'fan-speed'} = $value;
					}
				}
			}
		}
	}
	if ($path = main::check_program('aticonfig')){
		# aticonfig --adapter=0 --od-gettemperature
		@data = main::grabber("$path --adapter=all --od-gettemperature 2>/dev/null");
		foreach (@data){
			if (/Sensor [^0-9]*([0-9\.]+) /){
				$j = scalar @$gpu_data;
				my $value = $1;
				$gpu_data->[$j]{'type'} = 'amd';
				$gpu_data->[$j]{'temp'} = $value;
			}
		}
	}
	if ($sensors_raw->{'gpu'}){
		# my ($b_found,$holder) = (0,'');
		foreach my $adapter (keys %{$sensors_raw->{'gpu'}}){
			$j = scalar @$gpu_data;
			$gpu_data->[$j]{'type'} = $adapter;
			$gpu_data->[$j]{'type'} =~ s/^(amdgpu|intel|nouveau|nova|radeon)-.*/$1/;
			# print "ad: $adapter\n";
			foreach (@{$sensors_raw->{'gpu'}{$adapter}}){
				# print "val: $_\n";
				if (/^[^:]*mem[^:]*:([0-9\.]+).*\b(C|F)\b/i){
					$gpu_data->[$j]{'temp-mem'} = $1;
					$gpu_data->[$j]{'unit'} = $2;
					 # print "temp: $_\n";
				}
				elsif (/^[^:]+:([0-9\.]+).*\b(C|F)\b/i){
					$gpu_data->[$j]{'temp'} = $1;
					$gpu_data->[$j]{'unit'} = $2;
					 # print "temp: $_\n";
				}
				# speeds can be in percents or rpms, so need the 'fan' in regex
				elsif (/^.*?fan.*?:([0-9\.]+).*(RPM)?/i){
					$gpu_data->[$j]{'fan-speed'} = $1;
					# NOTE: we test for nvidia %, everything else stays with nothing
					$gpu_data->[$j]{'speed-unit'} = '';
				}
				elsif (/^[^:]+:([0-9\.]+)\s+W\s/i){
					$gpu_data->[$j]{'watts'} = $1;
				}
				elsif (/^[^:]+:([0-9\.]+)\s+(m?V)\s/i){
					$gpu_data->[$j]{'volts-gpu'} = [$1,$2];
				}
			}
		}
	}
	main::log_data('dump','sensors output: video: @$gpu_data',$gpu_data) if $b_log;
	print 'gpu_data: ', Data::Dumper::Dumper $gpu_data if $dbg[18];
	eval $end if $b_log;
}
}

## SlotItem
{