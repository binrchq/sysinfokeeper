package BatteryItem;
my (@upower_items,$b_upower,$upower);

sub get {
	eval $start if $b_log;
	my ($key1,$val1);
	my $battery = {};
	my $rows = [];
	my $num = 0;
	if ($force{'dmidecode'}){
		if ($alerts{'dmidecode'}->{'action'} ne 'use'){
			$key1 = $alerts{'dmidecode'}->{'action'};
			$val1 = $alerts{'dmidecode'}->{'message'};
			$key1 = ucfirst($key1);
			@$rows = ({main::key($num++,0,1,$key1) => $val1});
		}
		else {
			battery_data_dmi($battery);
			if (!%$battery){
				if ($show{'battery-forced'}){
					$key1 = 'Message';
					$val1 = main::message('battery-data','');
					@$rows = ({main::key($num++,0,1,$key1) => $val1});
				}
			}
			else {
				battery_output($rows,$battery);
			}
		}
	}
	elsif ($bsd_type && ($sysctl{'battery'} || $show{'battery-forced'})){
		battery_data_sysctl($battery) if $sysctl{'battery'};
		if (!%$battery){
			if ($show{'battery-forced'}){
				$key1 = 'Message';
				$val1 = main::message('battery-data-bsd','');
				@$rows = ({main::key($num++,0,1,$key1) => $val1});
			}
		}
		else {
			battery_output($rows,$battery);
		}
	}
	elsif (-d '/sys/class/power_supply/'){
		battery_data_sys($battery);
		if (!%$battery){
			if ($show{'battery-forced'}){
				$key1 = 'Message';
				$val1 = main::message('battery-data','');
				@$rows = ({main::key($num++,0,1,$key1) => $val1});
			}
		}
		else {
			battery_output($rows,$battery);
		}
	}
	else {
		if ($show{'battery-forced'}){
			$key1 = 'Message';
			$val1 = (!$bsd_type) ? main::message('battery-data-sys'): main::message('battery-data-bsd');
			@$rows = ({main::key($num++,0,1,$key1) => $val1});
		}
	}
	(@upower_items,$b_upower,$upower) = ();
	eval $end if $b_log;
	return $rows;
}

# alarm capacity capacity_level charge_full charge_full_design charge_now 
# cycle_count energy_full energy_full_design energy_now location manufacturer model_name 
# power_now present serial_number status technology type voltage_min_design voltage_now
# 0:  name - battery id, not used
# 1:  status
# 2:  present
# 3:  technology
# 4:  cycle_count
# 5:  voltage_min_design
# 6:  voltage_now
# 7:  power_now
# 8:  energy_full_design
# 9:  energy_full
# 10: energy_now
# 11: capacity
# 12: capacity_level
# 13: of_orig
# 14: model_name
# 15: manufacturer
# 16: serial_number
# 17: location
sub battery_output {
	eval $start if $b_log;
	my ($rows,$battery) = @_;
	my ($key);
	my $num = 0;
	my $j = 0;
	# print Data::Dumper::Dumper $battery;
	foreach $key (sort keys %$battery){
		$num = 0;
		my ($charge,$condition,$model,$serial,$status) = ('','','','','');
		my ($chemistry,$cycles,$location) = ('','','');
		next if !$battery->{$key}{'purpose'} || $battery->{$key}{'purpose'} ne 'primary';
		# $battery->{$key}{''};
		# we need to handle cases where charge or energy full is 0
		if (defined $battery->{$key}{'energy_now'} && $battery->{$key}{'energy_now'} ne ''){
			$charge = "$battery->{$key}{'energy_now'} Wh";
			if ($battery->{$key}{'energy_full'} && 
			 main::is_numeric($battery->{$key}{'energy_full'})){
				my $percent = sprintf("%.1f", $battery->{$key}{'energy_now'}/$battery->{$key}{'energy_full'}*100);
				$charge .= ' (' . $percent  . '%)';
			}
		}
		# better than nothing, shows the charged percent
		elsif (defined $battery->{$key}{'capacity'} && $battery->{$key}{'capacity'} ne ''){
			$charge = $battery->{$key}{'capacity'} . '%'
		}
		else {
			$charge = 'N/A';
		}
		if ($battery->{$key}{'energy_full'} || $battery->{$key}{'energy_full_design'}){
			$battery->{$key}{'energy_full_design'} ||= 'N/A';
			$battery->{$key}{'energy_full'} = (defined $battery->{$key}{'energy_full'} && 
			 $battery->{$key}{'energy_full'} ne '') ? $battery->{$key}{'energy_full'} : 'N/A';
			$condition = "$battery->{$key}{'energy_full'}/$battery->{$key}{'energy_full_design'} Wh";
			if ($battery->{$key}{'of_orig'}){
				$condition .= " ($battery->{$key}{'of_orig'}%)"; 
			}
		}
		$condition ||= 'N/A';
		$j = scalar @$rows;
		push(@$rows, {
		main::key($num++,1,1,'ID') => $key,
		main::key($num++,0,2,'charge') => $charge,
		main::key($num++,0,2,'condition') => $condition,
		});
		if ($extra > 2){
			if ($battery->{$key}{'power_now'}){
				$rows->[$j]{main::key($num++,0,2,'power')} = sprintf('%0.1f W',($battery->{$key}{'power_now'}/10**6));
			}
		}
		if ($extra > 0 || ($battery->{$key}{'voltage_now'} && 
		 $battery->{$key}{'voltage_min_design'} && 
		 ($battery->{$key}{'voltage_now'} - $battery->{$key}{'voltage_min_design'}) < 0.5)){
			$battery->{$key}{'voltage_now'} ||= 'N/A';
			$rows->[$j]{main::key($num++,1,2,'volts')} = $battery->{$key}{'voltage_now'};
			if ($battery->{$key}{'voltage_now'} ne 'N/A' || $battery->{$key}{'voltage_min_design'}){
				$battery->{$key}{'voltage_min_design'} ||= 'N/A';
				$rows->[$j]{main::key($num++,0,3,'min')} = $battery->{$key}{'voltage_min_design'};
			}
		}
		if ($extra > 0){
			if ($battery->{$key}{'manufacturer'} || $battery->{$key}{'model_name'}){
				if ($battery->{$key}{'manufacturer'} && $battery->{$key}{'model_name'}){
					$model = "$battery->{$key}{'manufacturer'} $battery->{$key}{'model_name'}";
				}
				elsif ($battery->{$key}{'manufacturer'}){
					$model = $battery->{$key}{'manufacturer'};
				}
				elsif ($battery->{$key}{'model_name'}){
					$model = $battery->{$key}{'model_name'};
				}
			}
			else {
				$model = 'N/A';
			}
			$rows->[$j]{main::key($num++,0,2,'model')} = $model;
			if ($extra > 2){
				$chemistry = ($battery->{$key}{'technology'}) ? $battery->{$key}{'technology'}: 'N/A';
				$rows->[$j]{main::key($num++,0,2,'type')} = $chemistry;
			}
			if ($extra > 1){
				$serial = main::filter($battery->{$key}{'serial_number'});
				$rows->[$j]{main::key($num++,0,2,'serial')} = $serial;
			}
			$status = ($battery->{$key}{'status'}) ? $battery->{$key}{'status'}: 'N/A';
			$rows->[$j]{main::key($num++,0,2,'status')} = $status;
			if ($extra > 2){
				if ($battery->{$key}{'cycle_count'}){
					$rows->[$j]{main::key($num++,0,2,'cycles')} = $battery->{$key}{'cycle_count'};
				}
				if ($battery->{$key}{'location'}){
					$rows->[$j]{main::key($num++,0,2,'location')} = $battery->{$key}{'location'};
				}
			}
		}
		$battery->{$key} = undef;
	}
	# print Data::Dumper::Dumper \%$battery;
	# now if there are any devices left, print them out, excluding Mains
	if ($extra > 0){
		$upower = main::check_program('upower');
		foreach $key (sort keys %$battery){
			$num = 0;
			next if !defined $battery->{$key} || $battery->{$key}{'purpose'} eq 'mains';
			my ($charge,$model,$serial,$percent,$status,$vendor) = ('','','','','','');
			$j = scalar @$rows;
			my $upower_data = ($upower) ? upower_data($key) : {};
			if ($upower_data->{'percent'}){
				$charge = $upower_data->{'percent'};
			}
			elsif ($battery->{$key}{'capacity_level'} &&
			 lc($battery->{$key}{'capacity_level'}) ne 'unknown'){
				$charge = $battery->{$key}{'capacity_level'};
			}
			else {
				$charge = 'N/A';
			}
			$model = $battery->{$key}{'model_name'} if $battery->{$key}{'model_name'};
			$vendor = $battery->{$key}{'manufacturer'} if $battery->{$key}{'manufacturer'};
			if ($vendor || $model){
				if ($vendor && $model){
					$model = "$vendor $model";
				}
				elsif ($vendor){
					$model = $vendor;
				}
			}
			else {
				$model = 'N/A';
			}
			push(@$rows, {
			main::key($num++,1,1,'Device') => $key,
			main::key($num++,0,2,'model') => $model,
			},);
			if ($extra > 1){
				$serial = main::filter($battery->{$key}{'serial_number'});
				$rows->[$j]{main::key($num++,0,2,'serial')} = $serial;
			}
			$rows->[$j]{main::key($num++,0,2,'charge')} = $charge;
			if ($extra > 2 && $upower_data->{'rechargeable'}){
				$rows->[$j]{main::key($num++,0,2,'rechargeable')} = $upower_data->{'rechargeable'};
			}
			$status = ($battery->{$key}{'status'}) ? $battery->{$key}{'status'}: 'N/A' ;
			$rows->[$j]{main::key($num++,0,2,'status')} = $status;
		}
	}
	eval $end if $b_log;
}

# charge: mAh energy: Wh
sub battery_data_sys {
	eval $start if $b_log;
	my $battery = $_[0];
	my ($b_ma,$file,$id,$item,$path,$value);
	my $num = 0;
	my @batteries = main::globber("/sys/class/power_supply/*");
	# note: there is no 'location' file, but dmidecode has it
	# 'type' is generic, like: Battery, Mains
	# capacity_level is a string, like: Normal
	my @items = qw(alarm capacity capacity_level charge_full charge_full_design 
	charge_now constant_charge_current constant_charge_current_max cycle_count 
	energy_full energy_full_design energy_now location manufacturer model_name 
	power_now present scope serial_number status technology type voltage_min_design 
	voltage_now);
	foreach $item (@batteries){
		$b_ma = 0;
		$id = $item;
		$id =~ s%/sys/class/power_supply/%%g;
		foreach $file (@items){
			$path = "$item/$file";
			# android shows some files only root readable
			$value = (-r $path) ? main::reader($path,'',0): '';
			# mains, plus in psu
			if ($file eq 'type' && $value && lc($value) ne 'battery'){
				$battery->{$id}{'purpose'} = 'mains';
			}
			if ($value){
				$value = main::trimmer($value);
				if ($file eq 'voltage_min_design'){
					$value = sprintf("%.1f", $value/1000000);
				}
				elsif ($file eq 'voltage_now'){
					$value = sprintf("%.1f", $value/1000000);
				}
				elsif ($file eq 'energy_full_design'){
					$value = $value/1000000;
				}
				elsif ($file eq 'energy_full'){
					$value = $value/1000000;
				}
				elsif ($file eq 'energy_now'){
					$value = sprintf("%.1f", $value/1000000);
				}
				# note: the following 3 were off, 100000 instead of 1000000
				# why this is, I do not know. I did not document any reason for that
				# so going on assumption it is a mistake. 
				# CHARGE is mAh, which are converted to Wh by: mAh x voltage. 
				# Note: voltage fluctuates so will make results vary slightly.
				elsif ($file eq 'charge_full_design'){
					$value = $value/1000000;
					$b_ma = 1;
				}
				elsif ($file eq 'charge_full'){
					$value = $value/1000000;
					$b_ma = 1;
				}
				elsif ($file eq 'charge_now'){
					$value = $value/1000000;
					$b_ma = 1;
				}
				elsif ($file eq 'manufacturer'){
					$value = main::clean_dmi($value);
				}
				elsif ($file eq 'model_name'){
					$value = main::clean_dmi($value);
				}
				# Valid values: Unknown,Charging,Discharging,Not charging,Full
				# don't use clean_unset because Not charging is a valid value.
				elsif ($file eq 'status'){
					$value = lc($value);
					$value =~ s/unknown//;
					
				}
			}
			elsif ($b_root && -e $path && ! -r $path){
				$value = main::message('root-required');
			}
			$battery->{$id}{$file} = $value;
			# print "$battery->{$id}{$file}\n";
		}
		# note, too few data sets, there could be sbs-charger but not sure
		if (!$battery->{$id}{'purpose'}){
			# NOTE: known ids: BAT[0-9] CMB[0-9]. arm may be like: sbs- sbm- but just check 
			# if the energy/charge values exist for this item, if so, it's a battery, if not, 
			# it's a device.
			if ($id =~ /^(BAT|CMB).*$/i || 
			 ($battery->{$id}{'energy_full'} || $battery->{$id}{'charge_full'} || 
			 $battery->{$id}{'energy_now'} || $battery->{$id}{'charge_now'} || 
			 $battery->{$id}{'energy_full_design'} || $battery->{$id}{'charge_full_design'}) || 
			 $battery->{$id}{'voltage_min_design'} || $battery->{$id}{'voltage_now'}){
				$battery->{$id}{'purpose'} =  'primary';
			}
			else {
				$battery->{$id}{'purpose'} =  'device';
			}
		}
		# note:voltage_now fluctuates, which will make capacity numbers change a bit
		# if any of these values failed, the math will be wrong, but no way to fix that
		# tests show more systems give right capacity/charge with voltage_min_design 
		# than with voltage_now
		if ($b_ma && $battery->{$id}{'voltage_min_design'}){
			if ($battery->{$id}{'charge_now'}){
				$battery->{$id}{'energy_now'} = $battery->{$id}{'charge_now'} * $battery->{$id}{'voltage_min_design'};
			}
			if ($battery->{$id}{'charge_full'}){
				$battery->{$id}{'energy_full'} = $battery->{$id}{'charge_full'}*$battery->{$id}{'voltage_min_design'};
			}
			if ($battery->{$id}{'charge_full_design'}){
				$battery->{$id}{'energy_full_design'} = $battery->{$id}{'charge_full_design'} * $battery->{$id}{'voltage_min_design'};
			}
		}
		if ($battery->{$id}{'energy_now'} && $battery->{$id}{'energy_full'}){
			$battery->{$id}{'capacity'} = 100 * $battery->{$id}{'energy_now'}/$battery->{$id}{'energy_full'};
			$battery->{$id}{'capacity'} = sprintf("%.1f", $battery->{$id}{'capacity'});
		}
		if ($battery->{$id}{'energy_full_design'} && $battery->{$id}{'energy_full'}){
			$battery->{$id}{'of_orig'} = 100 * $battery->{$id}{'energy_full'}/$battery->{$id}{'energy_full_design'};
			$battery->{$id}{'of_orig'} = sprintf("%.1f", $battery->{$id}{'of_orig'});
		}
		if ($battery->{$id}{'energy_now'}){
			$battery->{$id}{'energy_now'} = sprintf("%.1f", $battery->{$id}{'energy_now'});
		}
		if ($battery->{$id}{'energy_full_design'}){
			$battery->{$id}{'energy_full_design'} = sprintf("%.1f",$battery->{$id}{'energy_full_design'});
		}
		if ($battery->{$id}{'energy_full'}){
			$battery->{$id}{'energy_full'} = sprintf("%.1f", $battery->{$id}{'energy_full'});
		}
	}
	print Data::Dumper::Dumper $battery if $dbg[33];
	main::log_data('dump','sys: %$battery',$battery) if $b_log;
	eval $end if $b_log;
}

sub battery_data_sysctl {
	eval $start if $b_log;
	my $battery = $_[0];
	my ($id);
	for (@{$sysctl{'battery'}}){
		if (/^(hw\.sensors\.)acpi([^\.]+)(\.|:)/){
			$id = uc($2);
		}
		if (/volt[^:]+:([0-9\.]+)\s+VDC\s+\(voltage\)/){
			$battery->{$id}{'voltage_min_design'} = $1;
		}
		elsif (/volt[^:]+:([0-9\.]+)\s+VDC\s+\(current voltage\)/){
			$battery->{$id}{'voltage_now'} = $1;
		}
		elsif (/watthour[^:]+:([0-9\.]+)\s+Wh\s+\(design capacity\)/){
			$battery->{$id}{'energy_full_design'} = $1;
		}
		elsif (/watthour[^:]+:([0-9\.]+)\s+Wh\s+\(last full capacity\)/){
			$battery->{$id}{'energy_full'} = $1;
		}
		elsif (/watthour[^:]+:([0-9\.]+)\s+Wh\s+\(remaining capacity\)/){
			$battery->{$id}{'energy_now'} = $1;
		}
		elsif (/amphour[^:]+:([0-9\.]+)\s+Ah\s+\(design capacity\)/){
			$battery->{$id}{'charge_full_design'} = $1;
		}
		elsif (/amphour[^:]+:([0-9\.]+)\s+Ah\s+\(last full capacity\)/){
			$battery->{$id}{'charge_full'} = $1;
		}
		elsif (/amphour[^:]+:([0-9\.]+)\s+Ah\s+\(remaining capacity\)/){
			$battery->{$id}{'charge_now'} = $1;
		}
		elsif (/raw[^:]+:[0-9\.]+\s+\((battery) ([^\)]+)\)/){
			$battery->{$id}{'status'} = $2;
		}
		elsif (/^acpi[\S]+:at [^:]+:\s*$id\s+/i){
			if (/\s+model\s+(.*?)\s*/){
				$battery->{$id}{'model_name'} = main::clean_dmi($1);
			}
			if (/\s*serial\s+([\S]*?)\s*/){
				$battery->{$id}{'serial_number'} = main::clean_unset($1,'^(0x)0+$');
			}
			if (/\s*type\s+(.*?)\s*/){
				$battery->{$id}{'technology'} = $1;
			}
			if (/\s*oem\s+(.*)/){
				$battery->{$id}{'manufacturer'} = main::clean_dmi($1);
			}
		}
	}
	# then do the condition/charge percent math
	for my $id (keys %$battery){
		$battery->{$id}{'purpose'} = 'primary';
		# CHARGE is Ah, which are converted to Wh by: Ah x voltage. 
		if ($battery->{$id}{'voltage_min_design'}){
			if ($battery->{$id}{'charge_now'}){
				$battery->{$id}{'energy_now'} = $battery->{$id}{'charge_now'} * $battery->{$id}{'voltage_min_design'};
			}
			if ($battery->{$id}{'charge_full'}){
				$battery->{$id}{'energy_full'} = $battery->{$id}{'charge_full'}*$battery->{$id}{'voltage_min_design'};
			}
			if ($battery->{$id}{'charge_full_design'}){
				$battery->{$id}{'energy_full_design'} = $battery->{$id}{'charge_full_design'} * $battery->{$id}{'voltage_min_design'};
			}
		}
		if ($battery->{$id}{'energy_full_design'} && $battery->{$id}{'energy_full'}){
			$battery->{$id}{'of_orig'} = 100 * $battery->{$id}{'energy_full'}/$battery->{$id}{'energy_full_design'};
			$battery->{$id}{'of_orig'} = sprintf("%.1f", $battery->{$id}{'of_orig'});
		}
		if ($battery->{$id}{'energy_now'} && $battery->{$id}{'energy_full'}){
			$battery->{$id}{'capacity'} = 100 * $battery->{$id}{'energy_now'}/$battery->{$id}{'energy_full'};
			$battery->{$id}{'capacity'} = sprintf("%.1f", $battery->{$id}{'capacity'});
		}
		if ($battery->{$id}{'energy_now'}){
			$battery->{$id}{'energy_now'} = sprintf("%.1f", $battery->{$id}{'energy_now'});
		}
		if ($battery->{$id}{'energy_full'}){
			$battery->{$id}{'energy_full'} = sprintf("%.1f", $battery->{$id}{'energy_full'});
		}
		if ($battery->{$id}{'energy_full_design'}){
			$battery->{$id}{'energy_full_design'} = sprintf("%.1f", $battery->{$id}{'energy_full_design'});
		}
	}
	print Data::Dumper::Dumper $battery if $dbg[33];
	main::log_data('dump','dmi: %$battery',$battery) if $b_log;
	eval $end if $b_log;
}

# note, dmidecode does not have charge_now or charge_full
sub battery_data_dmi {
	eval $start if $b_log;
	my $battery = $_[0];
	my ($id);
	my $i = 0;
	foreach my $row (@dmi){
		# Portable Battery
		if ($row->[0] == 22){
			$id = "BAT$i";
			$i++;
			$battery->{$id}{'purpose'} = 'primary';
			# skip first three row, we don't need that data
			foreach my $item (@$row[3 .. $#$row]){
				my @value = split(/:\s+/, $item);
				next if !$value[0];
				if ($value[0] eq 'Location'){
					$battery->{$id}{'location'} = $value[1]}
				elsif ($value[0] eq 'Manufacturer'){
					$battery->{$id}{'manufacturer'} = main::clean_dmi($value[1])}
				elsif ($value[0] =~ /Chemistry/){
					$battery->{$id}{'technology'} = $value[1]}
				elsif ($value[0] =~ /Serial Number/){
					$battery->{$id}{'serial_number'} = $value[1]}
				elsif ($value[0] =~ /^Name/){
					$battery->{$id}{'model_name'} = main::clean_dmi($value[1])}
				elsif ($value[0] eq 'Design Capacity'){
					$value[1] =~ s/\s*mwh$//i;
					$battery->{$id}{'energy_full_design'} = sprintf("%.1f", $value[1]/1000);
				}
				elsif ($value[0] eq 'Design Voltage'){
					$value[1] =~ s/\s*mv$//i;
					$battery->{$id}{'voltage_min_design'} = sprintf("%.1f", $value[1]/1000);
				}
			}
			if ($battery->{$id}{'energy_now'} && $battery->{$id}{'energy_full'}){
				$battery->{$id}{'capacity'} = 100 * $battery->{$id}{'energy_now'} / $battery->{$id}{'energy_full'};
				$battery->{$id}{'capacity'} = sprintf("%.1f%", $battery->{$id}{'capacity'});
			}
			if ($battery->{$id}{'energy_full_design'} && $battery->{$id}{'energy_full'}){
				$battery->{$id}{'of_orig'} = 100 * $battery->{$id}{'energy_full'} / $battery->{$id}{'energy_full_design'};
				$battery->{$id}{'of_orig'} = sprintf("%.0f%", $battery->{$id}{'of_orig'});
			}
		}
		elsif ($row->[0] > 22){
			last;
		}
	}
	print Data::Dumper::Dumper $battery if $dbg[33];
	main::log_data('dump','dmi: %$battery',$battery) if $b_log;
	eval $end if $b_log;
}

sub upower_data {
	my ($id) = @_;
	eval $start if $b_log;
	my $data = {};
	if (!$b_upower && $upower){
		@upower_items = main::grabber("$upower -e 2>/dev/null",'','strip');
		$b_upower = 1;
	}
	if ($upower && @upower_items){
		foreach (@upower_items){
			if ($_ =~ /$id/){
				my @working = main::grabber("$upower -i $_ 2>/dev/null",'','strip');
				foreach my $row (@working){
					my @temp = split(/\s*:\s*/, $row);
					if ($temp[0] eq 'percentage'){
						$data->{'percent'} = $temp[1];
					}
					elsif ($temp[0] eq 'rechargeable'){
						$data->{'rechargeable'} = $temp[1];
					}
				}
				last;
			}
		}
	}
	main::log_data('dump','upower: %$data',$data) if $b_log;
	eval $end if $b_log;
	return $data;
}
}

## BluetoothItem 
{