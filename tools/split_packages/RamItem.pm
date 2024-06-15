package RamItem;
my ($speed_maps,$vendors,$vendor_ids);
my $ram_total = 0;
sub get {
	my ($key1,$val1);
	my ($ram,$rows) = ([],[]);
	my $num = 0;
	if ($bsd_type && !$force{'dmidecode'} && ($dboot{'ram'} || $fake{'dboot'})){
		dboot_data($ram);
		if (@$ram){
			ram_output($rows,$ram,'dboot');
		}
		else {
			$key1 = 'message';
			$val1 = main::message('ram-data-dmidecode');
			push(@$rows, {
			main::key($num++,1,1,'RAM Report') => '',
			main::key($num++,0,2,$key1) => $val1,
			});
		}
	}
	elsif (!$fake{'udevadm'} && !$force{'udevadm'} && ($fake{'dmidecode'} || 
	$alerts{'dmidecode'}->{'action'} eq 'use')){
		dmidecode_data($ram);
		if (@$ram){
			ram_output($rows,$ram,'dmidecode');
		}
		else {
			$key1 = 'message';
			$val1 = main::message('ram-data','dmidecode');
			push(@$rows, {
			main::key($num++,1,1,'RAM Report') => '',
			main::key($num++,0,2,$key1) => $val1,
			});
		}
	}
	elsif ($fake{'udevadm'} || $alerts{'udevadm'}->{'action'} eq 'use'){
		udevadm_data($ram);
		if (@$ram){
			ram_output($rows,$ram,'udevadm');
		}
		else {
			$key1 = 'message';
			my ($n,$v) = ProgramData::full('udevadm'); # v will be null/numeric start
			$v =~ s/^(\d+)([^\d].*)?/$1/ if $v;
			if ($v && $v < 249){
				$val1 = main::message('ram-udevadm-version',$v);
			}
			else {
				$val1 = main::message('ram-data','udevadm');
			}
			push(@$rows, {
			main::key($num++,1,1,'RAM Report') => '',
			main::key($num++,0,2,$key1) => $val1,
			});
		}
	}
	if (!$key1 && !@$ram) {
		$key1 = $alerts{'dmidecode'}->{'action'};
		$val1 = $alerts{'dmidecode'}->{'message'};
		push(@$rows, {
		main::key($num++,1,1,'RAM Report') => '',
		main::key($num++,0,2,$key1) => $val1,
		});
	}
	# we want the real installed RAM total if detected so add this after.
	if (!$loaded{'memory'}){
		$num = 0;
		my $system_ram = {};
		MemoryData::row('ram',$system_ram,\$num,1);
		unshift(@$rows,$system_ram);
	}
	($vendors,$vendor_ids) = ();
	eval $end if $b_log;
	return $rows;
}

sub ram_total {
	return $ram_total;
}

sub ram_output {
	eval $start if $b_log;
	my ($rows,$ram,$source) = @_;
	return if !@$ram;
	my $num = 0;
	my $j = 0;
	my $arrays = {};
	set_arrays_data($ram,$arrays);
	my ($b_non_system);
	if ($source eq 'dboot'){
		push(@$rows, {
		main::key($num++,0,1,'Message') => main::message('ram-data-complete'),
		});
	}
	# really only volts are inaccurate, possibly configured speed? Servers have
	# very poor data quality, so always show for udevadm and high slot counts
	# don't need t show for risc since if not dmi data, not running ram_output()
	if (!$show{'ram-short'} && $source eq 'udevadm' && 
	($extra > 1 || ($arrays->{'slots'} && $arrays->{'slots'} > 4))){
		my $message;
		if (!$b_root){
			$message = main::message('ram-udevadm');
		}
		elsif ($b_root && $alerts{'dmidecode'}->{'action'} eq 'missing'){
			$message = main::message('ram-udevadm-root');
		}
		if ($message){
			push(@$rows, {
			main::key($num++,1,1,'Message') => $message,
			});
		}
	}
	if (scalar @$ram > 1 || $show{'ram-short'}){
		arrays_output($rows,$ram,$arrays);
		if ($show{'ram-short'}){
			eval $end if $b_log;
			return 0;
		}
	}
	foreach my $item (@$ram){
		$j = scalar @$rows;
		$num = 1;
		$b_non_system = ($item->{'use'} && lc($item->{'use'}) ne 'system memory') ? 1: 0;
		push(@$rows, {
		main::key($num++,1,1,'Array') => '',
		main::key($num++,1,2,'capacity') => process_size($item->{'capacity'}),
		});
		if ($item->{'cap-qualifier'}){
			$rows->[$j]{main::key($num++,0,3,'note')} = $item->{'cap-qualifier'};
		}
		# show if > 1 array otherwise shows in System RAM line.
		if (scalar @$ram > 1){
			$rows->[$j]{main::key($num++,0,2,'installed')} = process_size($item->{'used-capacity'});
		}
		$rows->[$j]{main::key($num++,0,2,'use')} = $item->{'use'} if $b_non_system;
		$rows->[$j]{main::key($num++,1,2,'slots')} = $item->{'slots'};
		if ($item->{'slots-qualifier'}){
			$rows->[$j]{main::key($num++,0,3,'note')} = $item->{'slots-qualifier'};
		}
		$rows->[$j]{main::key($num++,0,2,'modules')} = $item->{'slots-active'};
		$item->{'eec'} ||= 'N/A';
		$rows->[$j]{main::key($num++,0,2,'EC')} = $item->{'eec'};
		if ($extra > 0 && (!$b_non_system || 
		(main::is_numeric($item->{'max-module-size'}) && 
		$item->{'max-module-size'} > 10))){
			$rows->[$j]{main::key($num++,1,2,'max-module-size')} = process_size($item->{'max-module-size'});
			if ($item->{'mod-qualifier'}){
				$rows->[$j]{main::key($num++,0,3,'note')} = $item->{'mod-qualifier'};
			}
		}
		if ($extra > 1 && $item->{'voltage'}){
			$rows->[$j]{main::key($num++,0,2,'voltage')} = $item->{'voltage'};
		}
		foreach my $entry ($item->{'modules'}){
			next if ref $entry ne 'ARRAY';
			# print Data::Dumper::Dumper $entry;
			foreach my $mod (@$entry){
				$num = 1;
				$j = scalar @$rows;
				# Multi array setups will start index at next from previous array
				next if ref $mod ne 'HASH';
				next if ($show{'ram-modules'} && $mod->{'size'} =~ /\D/);
				$mod->{'locator'} ||= 'N/A';
				push(@$rows, {
				main::key($num++,1,2,'Device') => $mod->{'locator'},
				});
				# This will contain the no module string
				if ($mod->{'size'} =~ /\D/){
					$rows->[$j]{main::key($num++,0,3,'type')} = lc($mod->{'size'});
					next;
				}
				if ($extra > 1 && $mod->{'type'}){
					$rows->[$j]{main::key($num++,0,3,'info')} = $mod->{'type'};
				}
				$mod->{'device-type'} ||= 'N/A';
				$rows->[$j]{main::key($num++,1,3,'type')} = $mod->{'device-type'};
				if ($extra > 2 && $mod->{'device-type'} ne 'N/A'){
					$mod->{'device-type-detail'} ||= 'N/A';
					$rows->[$j]{main::key($num++,0,4,'detail')} = $mod->{'device-type-detail'};
				}
				$rows->[$j]{main::key($num++,0,3,'size')} = process_size($mod->{'size'});
				if ($mod->{'speed'} && $mod->{'configured-clock-speed'} && 
				$mod->{'speed'} ne $mod->{'configured-clock-speed'}){
					$rows->[$j]{main::key($num++,1,3,'speed')} = '';
					$rows->[$j]{main::key($num++,0,4,'spec')} = $mod->{'speed'};
					if ($mod->{'speed-note'}){
						$rows->[$j]{main::key($num++,0,4,'note')} = $mod->{'speed-note'};
					}
					$rows->[$j]{main::key($num++,0,4,'actual')} = $mod->{'configured-clock-speed'};
					if ($mod->{'configured-note'}){
						$rows->[$j]{main::key($num++,0,5,'note')} = $mod->{'configured-note'};
					}
				}
				else {
					if (!$mod->{'speed'} && $mod->{'configured-clock-speed'}){
						if ($mod->{'configured-clock-speed'}){
							$mod->{'speed'} = $mod->{'configured-clock-speed'};
							if ($mod->{'configured-note'}){
								$mod->{'speed-note'} = $mod->{'configured-note'};
							}
						}
					}
					# Rare instances, dmi type 6, no speed, dboot also no speed
					$mod->{'speed'} ||= 'N/A';
					$rows->[$j]{main::key($num++,1,3,'speed')} = $mod->{'speed'};
					if ($mod->{'speed-note'}){
						$rows->[$j]{main::key($num++,0,4,'note')} = $mod->{'speed-note'};
					}
				}
				# Handle cases where -xx or -xxx and no voltage data (common) or voltages
				# are all the same.
				if ($extra > 1){
					if (($mod->{'voltage-config'} || $mod->{'voltage-max'} || 
					$mod->{'voltage-min'}) && ($b_admin || (
					($mod->{'voltage-config'} && $mod->{'voltage-max'} && 
					$mod->{'voltage-config'} ne $mod->{'voltage-max'}) || 
					($mod->{'voltage-config'} && $mod->{'voltage-min'} && 
					$mod->{'voltage-config'} ne $mod->{'voltage-min'}) || 
					($mod->{'voltage-min'} && $mod->{'voltage-max'} && 
					$mod->{'voltage-max'} ne $mod->{'voltage-min'})
					))){
						$rows->[$j]{main::key($num++,1,3,'volts')} = '';
						if ($mod->{'voltage-note'}){
							$rows->[$j]{main::key($num++,0,4,'note')} = $mod->{'voltage-note'};
						}
						if ($mod->{'voltage-config'}){
							$rows->[$j]{main::key($num++,0,4,'curr')} = $mod->{'voltage-config'};
						}
						if ($mod->{'voltage-min'}){
							$rows->[$j]{main::key($num++,0,4,'min')} = $mod->{'voltage-min'};
						}
						if ($mod->{'voltage-max'}){
							$rows->[$j]{main::key($num++,0,4,'max')} = $mod->{'voltage-max'};
						}
					}
					else {
						$mod->{'voltage-config'} ||= 'N/A';
						$rows->[$j]{main::key($num++,1,3,'volts')} = $mod->{'voltage-config'};
						if ($mod->{'voltage-note'}){
							$rows->[$j]{main::key($num++,0,4,'note')} = $mod->{'voltage-note'};
						}
					}
				}
				if ($source ne 'dboot'){
					if ($extra > 2){
						if (!$mod->{'data-width'} && !$mod->{'total-width'}){
							$rows->[$j]{main::key($num++,0,3,'width')} = 'N/A';
						}
						else {
							$rows->[$j]{main::key($num++,1,3,'width (bits)')} = '';
							$mod->{'data-width'} ||= 'N/A';
							$rows->[$j]{main::key($num++,0,4,'data')} = $mod->{'data-width'};
							$mod->{'total-width'} ||= 'N/A';
							$rows->[$j]{main::key($num++,0,4,'total')} = $mod->{'total-width'};
						}
					}
					if ($extra > 1){
						$mod->{'manufacturer'} ||= 'N/A';
						$rows->[$j]{main::key($num++,0,3,'manufacturer')} = $mod->{'manufacturer'};
						$mod->{'part-number'} ||= 'N/A';
						$rows->[$j]{main::key($num++,0,3,'part-no')} = $mod->{'part-number'};
					}
					if ($b_admin && $mod->{'firmware'}){
						$rows->[$j]{main::key($num++,0,3,'firmware')} = $mod->{'firmware'};
					}
					if ($extra > 2){
						$mod->{'serial'} = main::filter($mod->{'serial'});
						$rows->[$j]{main::key($num++,0,3,'serial')} = $mod->{'serial'};
					}
				}
			}
		}
	}
	eval $end if $b_log;
}

# args: 0: $rows ref; 1: $ram ref; 
sub arrays_output {
	eval $end if $b_log;
	my ($rows,$ram,$arrays) = @_;
	my $num = 1;
	$arrays->{'arrays'} ||= 'N/A';
	$arrays->{'capacity'} ||= 'N/A';
	$arrays->{'used-capacity'} ||= 'N/A';
	$arrays->{'eec'} ||= 'N/A';
	$arrays->{'slots'} ||= 'N/A';
	$arrays->{'slots-active'} ||= 'N/A';
	$arrays->{'device-type'} ||= 'N/A';
	push(@$rows, {
	main::key($num++,1,1,'Report') => '',
	main::key($num++,1,2,'arrays') => $arrays->{'arrays'},
	main::key($num++,1,2,'capacity') => process_size($arrays->{'capacity'}),
	main::key($num++,0,3,'installed') => process_size($arrays->{'used-capacity'}),
	main::key($num++,1,2,'slots') => $arrays->{'slots'},
	main::key($num++,0,3,'active') => $arrays->{'slots-active'},
	main::key($num++,0,2,'type') => $arrays->{'device-type'},
	main::key($num++,0,2,'eec') => $arrays->{'eec'},
	});
	eval $end if $b_log;
}

sub set_arrays_data {
	my ($ram,$arrays) = @_;
	$arrays->{'arrays'} = 0;
	$arrays->{'capacity'} = 0;
	$arrays->{'used-capacity'} = 0;
	$arrays->{'slots'} = 0;
	$arrays->{'slots-active'} = 0;
	foreach my $array (@$ram){
		$arrays->{'arrays'}++;
		$arrays->{'capacity'} += $array->{'capacity'} if $array->{'capacity'};
		$arrays->{'used-capacity'} += $array->{'used-capacity'} if $array->{'used-capacity'};
		$arrays->{'eec'} = $array->{'eec'} if !$arrays->{'eec'} && $array->{'eec'};
		$arrays->{'slots'} += $array->{'slots'} if $array->{'slots'};
		$arrays->{'slots-active'} += $array->{'slots-active'} if $array->{'slots-active'};
		$arrays->{'device-type'} = $array->{'device-type'} if !$arrays->{'device-type'} && $array->{'device-type'};
	}
}

# args: 0: $ram ref;
sub dboot_data {
	eval $start if $b_log;
	my $ram = $_[0];
	my $est = main::message('note-est');
	my ($arr,$derived_module_size,$subtract) = (0,0,0);
	my ($holder,@slots_active);
	foreach (@{$dboot{'ram'}}){
		my ($addr,$detail,$device_detail,$ecc,$iic,$locator,$size,$speed,$type);
		# Note: seen a netbsd with multiline spdmem0/1 etc but not consistent, don't use
		if (/^(spdmem([\d]+)):at iic([\d]+)(\saddr 0x([0-9a-f]+))?/){
			$iic = $3;
			$locator = $1;
			$holder = $iic if !defined $holder; # prime for first use
			# Note: seen iic2 as only device
			if ($iic != $holder){
				if ($ram->[$arr] && $ram->[$arr]{'slots-16'}){
					$subtract += $ram->[$arr]{'slots-16'};
				}
				$holder = $iic;
				# Then since we are on a new iic device, assume new ram array.
				# This needs more data to confirm this guess.
				$arr++; 
				$slots_active[$arr] = 0;
			}
			if ($5){
				$addr = hex($5);
			}
			if (/(non?[\s-]parity)/i){
				$device_detail = $1;
				$ecc = 'None';
			}
			elsif (/EEC/i){
				$device_detail = 'EEC';
				$ecc = 'EEC';
			}
			# Possible: PC2700CL2.5 PC3-10600
			if (/\b(PC([2-9]?-|)\d{4,})[^\d]/){
				$speed = $1;
				$speed =~ s/PC/PC-/ if $speed =~ /^PC\d{4}/;
				my $temp = speed_mapper($speed);
				if ($temp ne $speed){
					$detail = $speed;
					$speed = $temp;
				}
			}
			# We want to avoid netbsd trying to complete @ram without real data.
			if (/:(\d+[MGT])B?\s(DDR[0-9]*)\b/){
				$size = main::translate_size($1); # mbfix: /1024
				$type = $2;
				if ($addr){
					$ram->[$arr]{'slots-16'} = $addr - 80 + 1 - $subtract;
					$locator = 'Slot-' . $ram->[$arr]{'slots-16'};
				}
				$slots_active[$arr]++;
				$derived_module_size = $size if $size > $derived_module_size;
				$ram->[$arr]{'derived-module-size'} = $derived_module_size;
				$ram->[$arr]{'device-count-found'}++;
				$ram->[$arr]{'eec'} = $ecc if !$ram->[$arr]{'eec'} && $ecc;
				# Build up actual capacity found for override tests
				$ram->[$arr]{'max-capacity-16'} += $size;
				$ram->[$arr]{'max-cap-qualifier'} = $est;
				$ram->[$arr]{'slots-16'}++ if !$addr;
				$ram->[$arr]{'slots-active'} = $slots_active[$arr];
				$ram->[$arr]{'slots-qualifier'} = $est;
				$ram->[$arr]{'type'} = $type;
				$ram->[$arr]{'used-capacity'} += $size;
				if (!$ram->[$arr]{'device-type'} && $type){
					$ram->[$arr]{'device-type'} = $type;
				}
				push(@{$ram->[$arr]{'modules'}},{
				'device-type'  => $type,
				'device-type-detail'  => $detail,
				'locator' => $locator,
				'size' => $size,
				'speed' => $speed,
				});
			}
		}
	}
	for (my $i = 0; $i++ ;scalar @$ram){
		next if ref $ram->[$i] ne 'HASH';
		# 1 slot is possible, but 3 is very unlikely due to dual channel ddr
		if ($ram->[$i]{'slots'} && $ram->[$i]{'slots'} > 2 && $ram->[$i]{'slots'} % 2 == 1){
			$ram->[$i]{'slots'}++;
		}
	}
	print 'dboot pre process_data: ', Data::Dumper::Dumper $ram if $dbg[36];
	main::log_data('dump','@$ram',$ram) if $b_log;
	process_data($ram) if @$ram;
	main::log_data('dump','@$ram',$ram) if $b_log;
	print 'dboot post process_data: ', Data::Dumper::Dumper $ram if $dbg[36];
	eval $end if $b_log;
}

# args: 0: $ram ref;
sub dmidecode_data {
	eval $start if $b_log;
	my $ram = $_[0];
	my ($b_5,$handle,@slots_active,@temp);
	my ($derived_module_size,$max_cap_5,$max_cap_16,$max_module_size) = (0,0,0,0);
	my ($i,$j,$k) = (0,0,0);
	my $check = main::message('note-check');
	# print Data::Dumper::Dumper \@dmi;
	foreach my $entry (@dmi){
		## Note: do NOT reset these values, that causes failures
		# ($derived_module_size,$max_cap_5,$max_cap_16,$max_module_size) = (0,0,0,0);
		if ($entry->[0] == 5){
			$slots_active[$k] = 0;
			foreach my $item (@$entry){
				@temp = split(/:\s*/, $item, 2);
				next if !$temp[1];
				if ($temp[0] eq 'Maximum Memory Module Size'){
					$max_module_size = calculate_size($temp[1],$max_module_size);
					$ram->[$k]{'max-module-size'} = $max_module_size;
				}
				elsif ($temp[0] eq 'Maximum Total Memory Size'){
					$max_cap_5 = calculate_size($temp[1],$max_cap_5);
					$ram->[$k]{'max-capacity-5'} = $max_cap_5;
				}
				elsif ($temp[0] eq 'Memory Module Voltage'){
					$temp[1] =~ s/\s*V.*$//; # seen: 5.0 V 3.3 V
					$ram->[$k]{'voltage'} = $temp[1];
				}
				elsif ($temp[0] eq 'Associated Memory Slots'){
					$ram->[$k]{'slots-5'} = $temp[1];
				}
				elsif ($temp[0] eq 'Error Detecting Method'){
					$temp[1] ||= 'None';
					$ram->[$k]{'eec'} = $temp[1] if !$ram->[$k]{'eec'} && $temp[1];
				}
			}
			$ram->[$k]{'modules'} = [];
			# print Data::Dumper::Dumper \@ram;
			$b_5 = 1;
		}
		elsif ($entry->[0] == 6){
			my ($size,$speed,$type) = (0,0,0);
			my ($bank_locator,$device_type,$locator,$main_locator) = ('','','','');
			foreach my $item (@$entry){
				@temp = split(/:\s*/, $item, 2);
				next if !$temp[1];
				if ($temp[0] eq 'Installed Size'){
					# Get module size
					$size = calculate_size($temp[1],0);
					# Using this causes issues, really only works for 16
					# if ($size =~ /^[0-9][0-9]+$/){
					#		$ram->[$k]{'device-count-found'}++;
					#		$ram->[$k]{'used-capacity'} += $size;
					# }
					# Get data after module size
					$temp[1] =~ s/ Connection\)?//;
					$temp[1] =~ s/^[0-9]+\s*[KkMGTP]B\s*\(?//;
					$type = lc($temp[1]);
					$slots_active[$k]++;
				}
				elsif ($temp[0] eq 'Current Speed'){
					$speed = main::clean_dmi($temp[1]);
				}
				elsif ($temp[0] eq 'Locator' || $temp[0] eq 'Socket Designation'){
					$temp[1] =~ s/D?RAM slot #?/Slot/i; # can be with or without #
					$locator = $temp[1];
				}
				elsif ($temp[0] eq 'Bank Locator'){
					$bank_locator = $temp[1];
				}
				elsif ($temp[0] eq 'Type'){
					$device_type = main::clean_dmi($temp[1]);
				}
			}
			# Because of the wide range of bank/slot type data, we will just use
			# the one that seems most likely to be right. Some have: 
			# 'Bank: SO DIMM 0 slot: J6A' so we dump the useless data and use the 
			# one most likely to be visibly correct
			if ($bank_locator =~ /DIMM/){
				$main_locator = $bank_locator;
			}
			else {
				$main_locator = $locator;
			}
			$ram->[$k]{'modules'}[$j] = {
			'slots-active' => $slots_active[$k],
			'device-type' => $device_type,
			'locator' => $main_locator,
			'size' => $size,
			'speed' => $speed,
			'type' => $type,
			};
			if (!$ram->[$k]{'device-type'} && $device_type){
				$ram->[$k]{'device-type'} = $device_type;
			}
			# print Data::Dumper::Dumper \@ram;
			$j++;
		}
		elsif ($entry->[0] == 16){
			$handle = $entry->[1];
			$ram->[$handle] = $ram->[$k] if $ram->[$k];
			$ram->[$k] = undef;
			$slots_active[$handle] = 0;
			# ($derived_module_size,$max_cap_16) = (0,0);
			foreach my $item (@$entry){
				@temp = split(/:\s*/, $item, 2);
				next if !$temp[1];
				if ($temp[0] eq 'Maximum Capacity'){
					$max_cap_16 = calculate_size($temp[1],$max_cap_16);
					$ram->[$handle]{'max-capacity-16'} = $max_cap_16;
				}
				# Note: these 3 have cleaned data in DmiData, so replace stuff manually
				elsif ($temp[0] eq 'Location'){
					$temp[1] =~ s/\sOr\sMotherboard//;
					$temp[1] ||= 'System Board';
					$ram->[$handle]{'location'} = $temp[1];
				}
				elsif ($temp[0] eq 'Use'){
					$temp[1] ||= 'System Memory';
					$ram->[$handle]{'use'} = $temp[1];
				}
				elsif ($temp[0] eq 'Error Correction Type'){
					# seen <OUT OF SPEC>
					if ($temp[1] && lc($temp[1]) ne 'none'){
						$temp[1] = main::clean_dmi($temp[1]);
					}
					$temp[1] ||= 'None';
					if (!$ram->[$handle]{'eec'} && $temp[1]){
						$ram->[$handle]{'eec'} = $temp[1];
					}
				}
				elsif ($temp[0] eq 'Number Of Devices'){
					$ram->[$handle]{'slots-16'} = $temp[1];
				}
				# print "0: $temp[0]\n";
			}
			$ram->[$handle]{'derived-module-size'} = 0;
			$ram->[$handle]{'device-count-found'} = 0;
			$ram->[$handle]{'used-capacity'} = 0;
			# print "s16: $ram->[$handle]{'slots-16'}\n";
		}
		elsif ($entry->[0] == 17){
			my ($bank_locator,$configured_speed,$configured_note,
			$data_width) = ('','','','');
			my ($device_type,$device_type_detail,$firmware,$form_factor,$locator,
			$main_locator) = ('','','','','','');
			my ($manufacturer,$vendor_id,$part_number,$serial,$speed,$speed_note,
			$total_width) = ('','','','','','','');
			my ($voltage_config,$voltage_max,$voltage_min);
			my ($device_size,$i_data,$i_total,$working_size) = (0,0,0,0);
			foreach my $item (@$entry){
				@temp = split(/:\s*/, $item, 2);
				next if !$temp[1];
				if ($temp[0] eq 'Array Handle'){
					$handle = hex($temp[1]);
				}
				# These two can have 'none' or 'unknown' value
				elsif ($temp[0] eq 'Data Width'){
					$data_width = main::clean_dmi($temp[1]);
					$data_width =~ s/[\s_-]?bits// if $data_width;
				}
				elsif ($temp[0] eq 'Total Width'){
					$total_width = main::clean_dmi($temp[1]);
					$total_width =~ s/[\s_-]?bits// if $total_width;
				}
				# Do not try to guess from installed modules, only use this to correct 
				# type 5 data
				elsif ($temp[0] eq 'Size'){
					# we want any non real size data to be preserved
					if ($temp[1] =~ /^[0-9]+\s*[KkMTPG]i?B/){
						$derived_module_size = calculate_size($temp[1],$derived_module_size);
						$working_size = calculate_size($temp[1],0);
						$device_size = $working_size;
						$slots_active[$handle]++;
					}
					else {
						$device_size = ($temp[1] =~ /no module/i) ? main::message('ram-no-module') : $temp[1];
					}
				}
				elsif ($temp[0] eq 'Locator'){
					$temp[1] =~ s/D?RAM slot #?/Slot/i;
					$locator = $temp[1];
				}
				elsif ($temp[0] eq 'Bank Locator'){
					$bank_locator = $temp[1];
				}
				elsif ($temp[0] eq 'Form Factor'){
					$form_factor = $temp[1];
				}
				# these two can have 'none' or 'unknown' value
				elsif ($temp[0] eq 'Type'){
					$device_type = main::clean_dmi($temp[1]);
				}
				elsif ($temp[0] eq 'Type Detail'){
					$device_type_detail = main::clean_dmi($temp[1]);
				}
				elsif ($temp[0] eq 'Speed'){
					my ($working,$unit);
					$temp[1] = main::clean_dmi($temp[1]);
					if ($temp[1] && $temp[1] =~ /^(\d+)\s*([GM]\S+)/){
						$working = $1;
						$unit = $2;
						my $result = process_speed($unit,$working,$device_type,$check);
						($speed,$speed_note) = @$result;
					}
					else {
						$speed = $temp[1];
					}
				}
				# This is the actual speed the system booted at, speed is hardcoded
				# clock speed means MHz, memory speed MT/S
				elsif ($temp[0] eq 'Configured Clock Speed' || 
				$temp[0] eq 'Configured Memory Speed'){
					my ($working,$unit);
					$temp[1] = main::clean_dmi($temp[1]);
					if ($temp[1] && $temp[1] =~ /^(\d+)\s*([GM]\S+)/){
						$working = $1;
						$unit = $2;
						my $result = process_speed($unit,$working,$device_type,$check);
						($configured_speed,$configured_note) = @$result;
					}
					else {
						$speed = $temp[1];
					}
				}
				elsif ($temp[0] eq 'Firmware Version'){
					$temp[1] = main::clean_dmi($temp[1]);
					$firmware = $temp[1];
				}
				elsif ($temp[0] eq 'Manufacturer'){
					$temp[1] = main::clean_dmi($temp[1]);
					$manufacturer = $temp[1];
				}
				elsif ($temp[0] eq 'Part Number'){
					$part_number = main::clean_unset($temp[1],'^[0]+$|.*Module.*|PartNum.*');
				}
				elsif ($temp[0] eq 'Serial Number'){
					$serial = main::clean_unset($temp[1],'^[0]+$|SerNum.*');
				}
				elsif ($temp[0] eq 'Configured Voltage'){
					if ($temp[1] =~ /^([\d\.]+)/){
						$voltage_config = $1;
					}
				}
				elsif ($temp[0] eq 'Maximum Voltage'){
					if ($temp[1] =~ /^([\d\.]+)/){
						$voltage_max = $1;
					}
				}
				elsif ($temp[0] eq 'Minimum Voltage'){
					if ($temp[1] =~ /^([\d\.]+)/){
						$voltage_min = $1;
					}
				}
			}
			# locator data is not great or super reliable, so do our best
			$main_locator = process_locator($locator,$bank_locator);
			if ($working_size =~ /^[0-9][0-9]+$/){
				$ram->[$handle]{'device-count-found'}++;
				# build up actual capacity found for override tests
				$ram->[$handle]{'used-capacity'} += $working_size;
			}
			# Sometimes the data is just wrong, they reverse total/data. data I 
			# believe is used for the actual memory bus width, total is some synthetic 
			# thing, sometimes missing. Note that we do not want a regular string 
			# comparison, because 128 bit memory buses are in our future, and 
			# 128 bits < 64 bits with string compare.
			$data_width =~ /(^[0-9]+).*/;
			$i_data = $1;
			$total_width =~ /(^[0-9]+).*/;
			$i_total = $1;
			if ($i_data && $i_total && $i_data > $i_total){
				my $temp_width = $data_width;
				$data_width = $total_width;
				$total_width = $temp_width;
			}
			($manufacturer,$vendor_id,$part_number) = process_manufacturer(
			 $manufacturer,$part_number);
			if (!$ram->[$handle]{'device-type'} && $device_type){
				$ram->[$handle]{'device-type'} = $device_type;
			}
			$ram->[$handle]{'derived-module-size'} = $derived_module_size;
			$ram->[$handle]{'slots-active'} = $slots_active[$handle];
			$ram->[$handle]{'modules'}[$i]{'configured-clock-speed'} = $configured_speed;
			$ram->[$handle]{'modules'}[$i]{'configured-note'} = $configured_note if $configured_note;
			$ram->[$handle]{'modules'}[$i]{'data-width'} = $data_width;
			$ram->[$handle]{'modules'}[$i]{'size'} = $device_size;
			$ram->[$handle]{'modules'}[$i]{'device-type'} = $device_type;
			$ram->[$handle]{'modules'}[$i]{'device-type-detail'} = lc($device_type_detail);
			$ram->[$handle]{'modules'}[$i]{'firmware'} = $firmware;
			$ram->[$handle]{'modules'}[$i]{'form-factor'} = $form_factor;
			$ram->[$handle]{'modules'}[$i]{'locator'} = $main_locator;
			$ram->[$handle]{'modules'}[$i]{'manufacturer'} = $manufacturer;
			$ram->[$handle]{'modules'}[$i]{'vendor-id'} = $vendor_id;
			$ram->[$handle]{'modules'}[$i]{'part-number'} = $part_number;
			$ram->[$handle]{'modules'}[$i]{'serial'} = $serial;
			$ram->[$handle]{'modules'}[$i]{'speed'} = $speed;
			$ram->[$handle]{'modules'}[$i]{'speed-note'} = $speed_note if $speed_note;
			$ram->[$handle]{'modules'}[$i]{'total-width'} = $total_width;
			$ram->[$handle]{'modules'}[$i]{'voltage-config'} = $voltage_config;
			$ram->[$handle]{'modules'}[$i]{'voltage-max'} = $voltage_max;
			$ram->[$handle]{'modules'}[$i]{'voltage-min'} = $voltage_min;
			$i++
		}
		elsif ($entry->[0] < 17){
			next;
		}
		elsif ($entry->[0] > 17){
			last;
		}
	}
	print 'dmidecode pre process_data: ', Data::Dumper::Dumper $ram if $dbg[36];
	main::log_data('dump','pre @$ram',$ram) if $b_log;
	process_data($ram) if @$ram;
	main::log_data('dump','post @$ram',$ram) if $b_log;
	print 'dmidecode post process_data: ', Data::Dumper::Dumper $ram if $dbg[36];
	eval $end if $b_log;
}

# this contains a subset of dmi RAM data generated I believe at boot
# args: 0: $ram ref;
sub udevadm_data {
	eval $start if $b_log;
	my $ram = $_[0];
	my ($b_arr_nu,$b_arr_set,$d_holder,@data,$key,@temp);
	my ($a,$i) = (0,0);
	my %array_ids;
	if ($fake{'udevadm'}){
		my $file;
		# $file = "$fake_data_dir/ram/udevadm/udevadm-dmi-1-array-2-slot-1.txt";
		# $file = "$fake_data_dir/ram/udevadm/udevadm-dmi-1-array-2-slot-2-barebones.txt";
		# $file = "$fake_data_dir/ram/udevadm/udevadm-dmi-1-array-2-slot-3-errors.txt";
		# $file = "$fake_data_dir/ram/udevadm/udevadm-dmi-1-array-4-slot-1.txt";
		# $file = "$fake_data_dir/ram/udevadm/udevadm-dmi-1-array-4-slot-2-volts.txt";
		# $file = "$fake_data_dir/ram/udevadm/udevadm-dmi-1-array-16-slot-1.txt";
		# $file = "$fake_data_dir/ram/udevadm/udevadm-dmi-1-array-16-slot-2.txt";
		 $file = "$fake_data_dir/ram/udevadm/udevadm-dmi-2-array-24-slot-1.txt";
		# $file = "$fake_data_dir/ram/udevadm/udevadm-dmi-4-array-12-slot-1.txt";
		@data = main::reader($file,'strip');
	}
	else {
		my $cmd = $alerts{'udevadm'}->{'path'} . ' info -p /devices/virtual/dmi/id 2>/dev/null';
		@data = main::grabber($cmd,'','strip');
	}
	if (@data){
		@data = map {s/^\S: //;$_ if /^MEMORY/;} @data;
		# unknown if > 1 array output possible, do not sort in case they just stack it
		@data = grep {/^ME/} @data; 
	}
	main::log_data('dump','@data',\@data) if $b_log;
	print Data::Dumper::Dumper \@data if $dbg[36];
	foreach my $line (@data){
		@temp = split(/=/,$line,2);
		# there should be array numbering at least, but there isn't, not yet anyway
		if ($temp[0] =~ /^MEMORY_ARRAY_((\d+)_)?(\S+)/){
			$key = $3;
			if ($2){
				$b_arr_nu = 1;
				$a = $2;
			}
			# this _should_ be first item, hoping > 1 arrays is stacked in order
			if ($key eq 'LOCATION'){
				$temp[1] =~ s/\sOr\sMotherboard//;
				$temp[1] ||= 'System Board';
				$a++ if !$b_arr_nu && $b_arr_set;
				$ram->[$a]{'location'} = $temp[1];
				$b_arr_set = 1;
			}
			elsif ($key eq 'EC_TYPE'){
				if ($temp[1] && lc($temp[1]) ne 'none'){
					$temp[1] = main::clean_dmi($temp[1]); # seen <OUT OF SPEC>
				}
				$temp[1] ||= 'None';
				if (!$ram->[$a]{'eec'} && $temp[1]){
					$ram->[$a]{'eec'} = $temp[1];
				}
			}
			elsif ($key eq 'MAX_CAPACITY'){
				# in bytes
				$temp[1] = $temp[1]/1024 if $temp[1] =~ /^\d+$/;
				$ram->[$a]{'max-capacity-16'} = $temp[1];
			}
			elsif ($key eq 'NUM_DEVICES'){
				$ram->[$a]{'slots-16'} = $temp[1];
			}
			elsif ($key eq 'USE'){
				$temp[1] ||= 'System Memory';
				$ram->[$a]{'use'} = $temp[1];
			}
		}
		elsif ($temp[0] =~ /^MEMORY_DEVICE_(\d+)_(\S+)$/){
			$key = $2;
			if (!defined $d_holder){
				$d_holder = $1;
			}
			if ($d_holder ne $1){
				$i++;
				$d_holder = $1;
			}
			if ($key eq 'ASSET_TAG'){
				$temp[1] = main::clean_dmi($temp[1]);
				$ram->[$a]{'modules'}[$i]{'asset-tag'} = $temp[1] if $temp[1] ;
			}
			# only way to detect > 1 array systems is NODE[x] string.
			elsif ($key eq 'BANK_LOCATOR'){
				$ram->[$a]{'modules'}[$i]{'bank-locator'} = $temp[1];
				# this is VERY unreliable, but better than nothing. Update if needed and
				# new data sources available.
				if ($temp[1] =~ /Node[\s_-]?(\d+)/i){
					$ram->[$a]{'modules'}[$i]{'array-id'} = $1;
					$array_ids{$1} = 1 if !defined $array_ids{$1};
				}
			}
			elsif ($key eq 'CONFIGURED_SPEED_GTS'){
				$ram->[$a]{'modules'}[$i]{'configured-clock-speed'} = $temp[1];
				$ram->[$a]{'modules'}[$i]{'speed-unit'} = 'GT/s';
			}
			elsif ($key eq 'CONFIGURED_SPEED_MTS'){
				$ram->[$a]{'modules'}[$i]{'configured-clock-speed'} = $temp[1];
				$ram->[$a]{'modules'}[$i]{'speed-unit'} = 'MT/s';
			}
			elsif ($key eq 'CONFIGURED_VOLTAGE'){
				if ($temp[1] =~ /^([\d\.]+)/){
					$ram->[$a]{'modules'}[$i]{'voltage-config'} = $1;
				}
			}
			elsif ($key eq 'DATA_WIDTH'){
				$temp[1] = main::clean_dmi($temp[1]);
				if ($temp[1]){
					$temp[1] =~ s/[\s_-]?bits//;
					$temp[1] =~ /(^[0-9]+).*/;
					$ram->[$a]{'modules'}[$i]{'data-width'} = $1;
				}
			}
			elsif ($key eq 'FIRMWARE_VERSION'){
				$ram->[$a]{'modules'}[$i]{'firmware'} = main::clean_dmi($temp[1]);
			}
			elsif ($key eq 'FORM_FACTOR'){
				$ram->[$a]{'modules'}[$i]{'form-factor'} = main::clean_dmi($temp[1]);
			}
			elsif ($key eq 'LOCATOR'){
				$ram->[$a]{'modules'}[$i]{'locator'} = $temp[1];
			}
			elsif ($key eq 'MANUFACTURER'){
				$temp[1] = main::clean_dmi($temp[1]);
				$ram->[$a]{'modules'}[$i]{'manufacturer'} = $temp[1];
			}
			elsif ($key eq 'MAXIMUM_VOLTAGE'){
				if ($temp[1] =~ /^([\d\.]+)/){
					$ram->[$a]{'modules'}[$i]{'voltage-max'} = $1;
				}
			}
			elsif ($key eq 'MINIMUM_VOLTAGE'){
				if ($temp[1] =~ /^([\d\.]+)/){
					$ram->[$a]{'modules'}[$i]{'voltage-min'} = $1;
				}
			}
			elsif ($key eq 'PART_NUMBER'){
				$ram->[$a]{'modules'}[$i]{'part-number'} = main::clean_unset($temp[1],'^[0]+$|.*Module.*|PartNum.*');
			}
			elsif ($key eq 'PRESENT'){
				$ram->[$a]{'modules'}[$i]{'present'} = $temp[1]; # 0/1
			}
			elsif ($key eq 'RANK'){
				$ram->[$a]{'modules'}[$i]{'rank'} = $temp[1]; 
			}
			elsif ($key eq 'SERIAL_NUMBER'){
				$ram->[$a]{'modules'}[$i]{'serial'} = main::clean_unset($temp[1],'^[0]+$|SerNum.*');
			}
			# only seems to appear if occupied, handle no value in process
			elsif ($key eq 'SIZE'){
				if ($temp[1] =~ /^\d+$/){
					$temp[1] = $temp[1]/1024;
					$ram->[$a]{'modules'}[$i]{'size'} = $temp[1];
				}
			}
			# maybe with DDR6 or 7?
			elsif ($key eq 'SPEED_GTS'){
				$ram->[$a]{'modules'}[$i]{'speed'} = $temp[1];
				$ram->[$a]{'modules'}[$i]{'speed-unit'} = 'GT/s';
			}
			elsif ($key eq 'SPEED_MTS'){
				$ram->[$a]{'modules'}[$i]{'speed'} = $temp[1];
				$ram->[$a]{'modules'}[$i]{'speed-unit'} = 'MT/s';
			}
			elsif ($key eq 'TOTAL_WIDTH'){
				$temp[1] = main::clean_dmi($temp[1]);
				if ($temp[1]){
					$temp[1] =~ s/[\s_-]?bits//;
					$temp[1] =~ /(^[0-9]+).*/;
					$ram->[$a]{'modules'}[$i]{'total-width'} = $1;
				}
			}
			elsif ($key eq 'TYPE'){
				$ram->[$a]{'modules'}[$i]{'device-type'} = main::clean_dmi($temp[1]);
				if (!$ram->[$a]{'device-type'} && $ram->[$a]{'modules'}[$i]{'device-type'}){
					$ram->[$a]{'device-type'} = $ram->[$a]{'modules'}[$i]{'device-type'};
				}
			}
			elsif ($key eq 'TYPE_DETAIL'){
				$ram->[$a]{'modules'}[$i]{'device-type-detail'} = lc(main::clean_dmi($temp[1]));
			}
		}
	}
	print 'udevadm pre process_data: ', Data::Dumper::Dumper $ram if $dbg[36];
	main::log_data('dump','pre @$ram',$ram) if $b_log;
	# bad quality output, for > 1 arrays, shows 1 array, > 1 nodes.
	if (scalar @$ram == 1 && %array_ids && scalar keys %array_ids > 1){
		udevadm_create_arrays($ram);
	}
	if (@$ram){
		udevadm_data_process($ram);
	}
	process_data($ram) if @$ram;
	main::log_data('dump','post @$ram',$ram) if $b_log;
	print 'udevadm post process_data: ', Data::Dumper::Dumper $ram if $dbg[36];
	eval $end if $b_log;
}

# args: 0: $ram ref; 
sub udevadm_create_arrays {
	eval $start if $b_log;
	my $ram = $_[0];
	my ($id,%working);
	# rebuild the single array into set of arrays
	my $arr = shift @$ram;
	foreach my $module (@{$arr->{'modules'}}){
		$id = $module->{'array-id'};
		push(@{$working{$id}->{'modules'}},$module);
	}
	# print Data::Dumper::Dumper \%working;
	my $i = 0;
	foreach my $key (sort {$a <=> $b} keys %working){
		$ram->[$i]{'modules'} = $working{$key}->{'modules'};
		foreach my $key2 (%$arr){
			next if $key2 eq 'modules' || $key2 eq 'slots-16';
			$ram->[$i]{$key2} = $arr->{$key2};
		}
		$ram->[$i]{'slots-16'} = scalar @{$working{$key}->{'modules'}};
		$i++;
	}
	# print Data::Dumper::Dumper $ram;
	eval $end if $b_log;
}

# See comments on dmidecode_data modules for logic used here
# args: 0: $ram ref;
sub udevadm_data_process {
	eval $start if $b_log;
	my $ram = $_[0];
	my ($derived_module_size) = (0);
	my $check = main::message('note-check');
	# print 'post udev create: ', Data::Dumper::Dumper $ram;
	for (my $a=0; $a < scalar @$ram; $a++){
		# set the working data
		$ram->[$a]{'derived-module-size'} = 0;
		$ram->[$a]{'device-count-found'} = 0;
		$ram->[$a]{'used-capacity'} = 0;
		$ram->[$a]{'eec'} ||= 'None';
		$ram->[$a]{'use'} ||= 'System Memory';
		for (my $i=0; $i < scalar @{$ram->[$a]{'modules'}}; $i++){
			if ($ram->[$a]{'modules'}[$i]{'size'}){
				$derived_module_size = calculate_size($ram->[$a]{'modules'}[$i]{'size'}.'KiB',$derived_module_size);
				$ram->[$a]{'device-count-found'}++;
				$ram->[$a]{'slots-active'}++;
				$ram->[$a]{'used-capacity'} += $ram->[$a]{'modules'}[$i]{'size'};
			}
			elsif (!$ram->[$a]{'modules'}[$i]{'size'}){
				$ram->[$a]{'modules'}[$i]{'size'} = main::message('ram-no-module');
			}
			# sometimes all upper case, no idea why
			if ($ram->[$a]{'modules'}[$i]{'manufacturer'} || 
			$ram->[$a]{'modules'}[$i]{'part-number'}){
				($ram->[$a]{'modules'}[$i]{'manufacturer'},
				$ram->[$a]{'modules'}[$i]{'vendor-id'},
				$ram->[$a]{'modules'}[$i]{'part-number'}) = process_manufacturer(
				 $ram->[$a]{'modules'}[$i]{'manufacturer'},
				 $ram->[$a]{'modules'}[$i]{'part-number'});
			}
			# these are sometimes reversed
			if ($ram->[$a]{'modules'}[$i]{'data-width'} && 
			$ram->[$a]{'modules'}[$i]{'total-width'} && 
			$ram->[$a]{'modules'}[$i]{'data-width'} > $ram->[$a]{'modules'}[$i]{'total-width'}){
				my $temp = $ram->[$a]{'modules'}[$i]{'data-width'};
				$ram->[$a]{'modules'}[$i]{'data-width'} = $ram->[$a]{'modules'}[$i]{'total-width'};
				$ram->[$a]{'modules'}[$i]{'total-width'} = $temp;
			}
			if ($ram->[$a]{'modules'}[$i]{'speed'}){
				my $result = process_speed($ram->[$a]{'modules'}[$i]{'speed-unit'},
				 $ram->[$a]{'modules'}[$i]{'speed'},
				 $ram->[$a]{'modules'}[$i]{'device-type'},$check);
				$ram->[$a]{'modules'}[$i]{'speed'} = $result->[0];
				$ram->[$a]{'modules'}[$i]{'speed-note'} = $result->[1];
			}
			if ($ram->[$a]{'modules'}[$i]{'configured-clock-speed'}){
				my $result = process_speed($ram->[$a]{'modules'}[$i]{'speed-unit'},
				 $ram->[$a]{'modules'}[$i]{'configured-clock-speed'},
				 $ram->[$a]{'modules'}[$i]{'device-type'},$check);
				$ram->[$a]{'modules'}[$i]{'configured-clock-speed'} = $result->[0];
				$ram->[$a]{'modules'}[$i]{'configured-note'} = $result->[1];
			}
			# odd case were all value 1, which is almost certainly wrong
			if ($ram->[$a]{'modules'}[$i]{'voltage-min'} && 
			$ram->[$a]{'modules'}[$i]{'voltage-max'} && 
			$ram->[$a]{'modules'}[$i]{'voltage-config'} && 
			$ram->[$a]{'modules'}[$i]{'voltage-min'} eq '1' && 
			$ram->[$a]{'modules'}[$i]{'voltage-max'} eq '1' && 
			$ram->[$a]{'modules'}[$i]{'voltage-config'} eq '1'){
				$ram->[$a]{'modules'}[$i]{'voltage-note'} = $check;
			}
			if ($ram->[$a]{'modules'}[$i]{'locator'} && 
			$ram->[$a]{'modules'}[$i]{'bank-locator'}){
				$ram->[$a]{'modules'}[$i]{'locator'} = process_locator(
				 $ram->[$a]{'modules'}[$i]{'locator'},$ram->[$a]{'modules'}[$i]{'bank-locator'});
			}
		}
		$ram->[$a]{'derived-module-size'} = $derived_module_size if $derived_module_size;
	}
	eval $end if $b_log;
}

sub process_data {
	eval $start if $b_log;
	my $ram = $_[0];
	my @result;
	my $b_debug = 0;
	my $check = main::message('note-check');
	my $est = main::message('note-est');
	foreach my $item (@$ram){
		# Because we use the actual array handle as the index, there will be many 
		# undefined keys.
		next if ! defined $item;
		my ($max_cap,$max_mod_size) = (0,0);
		my ($alt_cap,$est_cap,$est_mod,$est_slots,$unit) = (0,'','','','');
		$max_cap = $item->{'max-capacity-16'};
		$max_cap ||= 0;
		# Make sure they are integers not string if empty.
		$item->{'slots-5'} ||= 0; 
		$item->{'slots-16'} ||= 0; 
		$item->{'slots-active'} ||= 0; 
		$item->{'device-count-found'} ||= 0;
		$item->{'max-capacity-5'} ||= 0;
		$item->{'max-module-size'} ||= 0;
		$item->{'used-capacity'} ||= 0;
		# $item->{'max-module-size'} = 0;# debugger
		# 1: If max cap 1 is null, and max cap 2 not null, use 2
		if ($b_debug){
			print "1: mms: $item->{'max-module-size'} :dms: $item->{'derived-module-size'} ";
			print ":mc: $max_cap :uc: $item->{'used-capacity'}\n";
			print "1a: s5: $item->{'slots-5'} s16: $item->{'slots-16'}\n";
		}
		if (!$max_cap && $item->{'max-capacity-5'}){
			$max_cap = $item->{'max-capacity-5'};
		}
		if ($b_debug){
			print "2: mms: $item->{'max-module-size'} :dms: $item->{'derived-module-size'} ";
			print ":mc: $max_cap :uc: $item->{'used-capacity'}\n";
		}
		# 2: Now check to see if actually found module sizes are > than listed 
		# max module, replace if >
		if ($item->{'max-module-size'} && $item->{'derived-module-size'} && 
		$item->{'derived-module-size'} > $item->{'max-module-size'}){
			$item->{'max-module-size'} = $item->{'derived-module-size'};
			$est_mod = $est;
		}
		if ($b_debug){
			print "3: dcf: $item->{'device-count-found'} :dms: $item->{'derived-module-size'} ";
			print ":mc: $max_cap :uc: $item->{'used-capacity'}\n";
		}
		# Note: some cases memory capacity == max module size, so one stick will 
		# fill it but I think only with cases of 2 slots does this happen, so 
		# if > 2, use the count of slots.
		if ($max_cap && ($item->{'device-count-found'} || $item->{'slots-16'})){
			# First check that actual memory found is not greater than listed max cap,
			# or checking to see module count * max mod size is not > used capacity
			if ($item->{'used-capacity'} && $item->{'max-capacity-16'}){
				if ($item->{'used-capacity'} > $max_cap){
					if ($item->{'max-module-size'} && 
					$item->{'used-capacity'} < ($item->{'slots-16'} * $item->{'max-module-size'})){
						$max_cap = $item->{'slots-16'} * $item->{'max-module-size'};
						$est_cap = $est;
						print "A\n" if $b_debug;
					}
					elsif ($item->{'derived-module-size'} && 
					$item->{'used-capacity'} < ($item->{'slots-16'} * $item->{'derived-module-size'})){
						$max_cap = $item->{'slots-16'} * $item->{'derived-module-size'};
						$est_cap = $est;
						print "B\n" if $b_debug;
					}
					else {
						$max_cap = $item->{'used-capacity'};
						$est_cap = $est;
						print "C\n" if $b_debug;
					}
				}
			}
			# Note that second case will never really activate except on virtual 
			# machines and maybe mobile devices.
			if (!$est_cap){
				# Do not do this for only single modules found, max mod size can be 
				# equal to the array size.
				if ($item->{'slots-16'} > 1 && $item->{'device-count-found'} > 1 && 
				$max_cap < ($item->{'derived-module-size'} * $item->{'slots-16'})){
					$max_cap = $item->{'derived-module-size'} * $item->{'slots-16'};
					$est_cap = $est;
					print "D\n" if $b_debug;
				}
				elsif ($item->{'device-count-found'} > 0 && 
				$max_cap < ($item->{'derived-module-size'} * $item->{'device-count-found'})){
					$max_cap = $item->{'derived-module-size'} * $item->{'device-count-found'};
					$est_cap = $est;
					print "E\n" if $b_debug;
				}
				# Handle cases where we have type 5 data: mms x device count equals 
				# type 5 max caphowever do not use it if cap / devices equals the 
				# derived module size.
				elsif ($item->{'max-module-size'} > 0 &&
				($item->{'max-module-size'} * $item->{'slots-16'}) == $item->{'max-capacity-5'} &&
				$item->{'max-capacity-5'} != $item->{'max-capacity-16'} &&
				$item->{'derived-module-size'} != ($item->{'max-capacity-16'}/$item->{'slots-16'})){
					$max_cap = $item->{'max-capacity-5'};
					$est_cap = $est;
					print "F\n" if $b_debug;
				}
				
			}
			if ($b_debug){
				print "4: mms: $item->{'max-module-size'} :dms: $item->{'derived-module-size'} ";
				print ":mc: $max_cap :uc: $item->{'used-capacity'}\n";
			}
			# Some cases of type 5 have too big module max size, just dump the data 
			# then since we cannot know if it is valid or not, and a guess can be 
			# wrong easily.
			if ($item->{'max-module-size'} && $max_cap && $item->{'max-module-size'} > $max_cap){
				$item->{'max-module-size'} = 0;
			}
			if ($b_debug){
				print "5: dms: $item->{'derived-module-size'} :s16: $item->{'slots-16'} :mc: $max_cap\n";
			}
			# Now prep for rebuilding the ram array data.
			if (!$item->{'max-module-size'}){
				# ie: 2x4gB
				if (!$est_cap && $item->{'derived-module-size'} > 0 && 
				$max_cap > ($item->{'derived-module-size'} * $item->{'slots-16'} * 4)){
					$est_cap = $check;
					print "G\n" if $b_debug;
				}
				if ($max_cap && ($item->{'slots-16'} || $item->{'slots-5'})){
					my $slots = 0;
					if ($item->{'slots-16'} && $item->{'slots-16'} >= $item->{'slots-5'}){
						$slots = $item->{'slots-16'};
					}
					elsif ($item->{'slots-5'} && $item->{'slots-5'} > $item->{'slots-16'}){
						$slots = $item->{'slots-5'};
					}
					# print "slots: $slots\n" if $b_debug;
					if ($item->{'derived-module-size'} * $slots > $max_cap){
						$item->{'max-module-size'} = $item->{'derived-module-size'};
						print "H\n" if $b_debug;
					}
					else {
						$item->{'max-module-size'} = sprintf("%.f",$max_cap/$slots);
						print "J\n" if $b_debug;
					}
					$est_mod = $est;
				}
			}
			# Case where listed max cap is too big for actual slots x max cap, eg:
			# listed max cap, 8gb, max mod 2gb, slots 2
			else {
				if (!$est_cap && $item->{'max-module-size'} > 0){
					if ($max_cap > ($item->{'max-module-size'} * $item->{'slots-16'})){
						$est_cap = $check;
						print "K\n" if $b_debug;
					}
				}
			}
		}
		# No slots found due to legacy dmi probably. Note, too many logic errors
		# happen if we just set a general slots above, so safest to do it here
		$item->{'slots-16'} = $item->{'slots-5'} if $item->{'slots-5'} && !$item->{'slots-16'};
		if (!$item->{'slots-16'} && $item->{'modules'} && ref $item->{'modules'} eq 'ARRAY'){
			$est_slots = $check;
			$item->{'slots-16'} = scalar @{$item->{'modules'}};
			print "L\n" if $b_debug;
		}
		# Only bsds using dmesg data
		elsif ($item->{'slots-qualifier'}){
			$est_slots = $item->{'slots-qualifier'};
			$est_cap = $est;
		}
		$ram_total += $item->{'used-capacity'};
		push(@result, {
		'capacity' => $max_cap,
		'cap-qualifier' => $est_cap,
		'device-type' => $item->{'device-type'},
		'eec' => $item->{'eec'},
		'location' => $item->{'location'},
		'max-module-size' => $item->{'max-module-size'},
		'mod-qualifier' => $est_mod,
		'modules' => $item->{'modules'},
		'slots' => $item->{'slots-16'},
		'slots-active' => $item->{'slots-active'},
		'slots-qualifier' => $est_slots,
		'use' => $item->{'use'},
		'used-capacity' => $item->{'used-capacity'},
		'voltage-config' => $item->{'voltage-config'},
		'voltage-max' => $item->{'voltage-max'},
		'voltage-min' => $item->{'voltage-min'},
		});
	}
	@$ram = @result;
	eval $end if $b_log;
}

## RAM UTILITIES ##

# arg: 0: size string; 1: working size. If calculated result > $size, uses new
# value. If $data not valid, returns 0.
sub calculate_size {
	eval $start if $b_log;
	my ($data, $size) = @_;
	# Technically k is KiB, K is KB but can't trust that.
	if ($data =~ /^([0-9]+\s*[kKGMTP])i?B/){
		my $working = $1;
		# This converts it to KiB
		my $working_size = main::translate_size($working);
		# print "ws-a: $working_size s-1: $size\n";
		if (main::is_numeric($working_size) && $working_size > $size){
			$size = $working_size;
		}
		# print "ws-b: $working_size s-2: $size\n";
	}
	else {
		$size = 0;
	}
	# print "d-2: $data s-3: $size\n";
	eval $end if $b_log;
	return $size;
}

# Because of the wide range of bank/slot type data, we will just use the 
# one that seems most likely to be right. Some have: 
# 'Bank: SO DIMM 0 slot: J6A' so we dump the useless data and use the one 
# most likely to be visibly correct.
# Some systems show only DIMM 1 etc for locator with > 1 channels.
# args: 0: locator; 1: bank-locator
sub process_locator {
	eval $start if $b_log;
	my ($locator,$bank_locator) = @_;
	my $main_locator;
	if ($bank_locator && $bank_locator =~ /DIMM/){
		$main_locator = $bank_locator;
	}
	else {
		# some systems show only DIMM 1 etc for locator with > 1 channels.
		if ($locator && $locator =~ /^DIMM[\s_-]?\d+$/ && 
		$bank_locator && $bank_locator =~ /Channel[\s_-]?([A-Z]+)/i){
			$main_locator = "Channel-$1 $locator";
		}
		else {
			$main_locator = $locator;
		}
	}
	eval $end if $b_log;
	return $main_locator;
}

# args: 0: manufacturer; 1: part number
sub process_manufacturer {
	eval $start if $b_log;
	my ($manufacturer,$part_number) = @_;
	my $vendor_id;
	if ($manufacturer){
		if ($manufacturer =~ /^([a-f0-9]{4})$/i){
			$vendor_id = lc($1);
			$manufacturer = '';
		}
		elsif ($manufacturer =~ /^[A-Z]+$/){
			$manufacturer = ucfirst(lc($manufacturer));
		}
	}
	if (!$manufacturer){
		if ($part_number){
			my $result = ram_vendor($part_number);
			$manufacturer = $result->[0] if $result->[0];
			$part_number = $result->[1] if $result->[1];
		}
		if (!$manufacturer && $vendor_id){
			set_ram_vendor_ids() if !$vendor_ids;
			if ($vendor_ids->{$vendor_id}){
				$manufacturer = $vendor_ids->{$vendor_id};
			}
			else {
				$manufacturer = $vendor_id;
			}
		}
	}
	eval $end if $b_log;
	return ($manufacturer,$vendor_id,$part_number);
}

# args: 0: size in KiB
sub process_size {
	eval $start if $b_log;
	my ($size) = @_;
	my ($b_trim,$unit) = (0,'');
	# print "size0: $size\n";
	return 'N/A' if !$size;
	# we're going to preserve the bad data for output
	return $size if !main::is_numeric($size);
	# print "size: $size\n";
	# We only want max 2 decimal places, and only when it's a unit > 1 GiB.
	$b_trim = 1 if $size > 1024**2;
	($size,$unit) = main::get_size($size);
	$size = sprintf("%.2f",$size) if $b_trim;
	$size =~ s/\.[0]+$//;
	$size = "$size $unit";
	eval $end if $b_log;
	return $size;
}

# args: 0: speed unit; 1: speed (numeric); 2: device tyep; 3: check string
sub process_speed {
	eval $start if $b_log;
	my ($unit,$speed,$device_type,$check) = @_;
	my ($speed_note,$speed_orig);
	if ($unit eq 'MHz' && $device_type && $device_type =~ /ddr/i && $speed){
		$speed_orig = " ($speed $unit)";
		$speed = ($speed * 2);
		$unit = 'MT/s';
	}
	# Seen cases of 1 MT/s, 61690 MT/s, not sure why, bug. Crucial is shipping 
	# 5100 MT/s now, and 6666 has been hit, so speeds can hit 10k. DDR6 hits 
	# 12.8k-17k, DDR7?. If GT/s assume valid and working
	if ($speed && $unit && $unit eq 'MT/s'){
		if ($speed < 50 || $speed > 30000){
			$speed_note = $check;
		}
	}
	$speed .= " $unit";
	$speed .= $speed_orig if $speed_orig;
	eval $end if $b_log;
	return [$speed,$speed_note];
}

# BSD: Map string to speed, in MT/s
sub set_speed_maps {
	$speed_maps = {
	# DDR1
	'PC-1600' => 200,
	'PC-2100' => 266,
	'PC-2400' => 300,
	'PC-2700' => 333,
	'PC-3200' => 400,
	# DDR2
	'PC2-3200' => 400,
	'PC2-4200' => 533,
	'PC2-5300' => 667,
	'PC2-6400' => 800,
	'PC2-8000' => 1000,
	'PC2-8500' => 1066,
	# DDR3
	'PC3-6400' => 800,
	'PC3-8500' => 1066,
	'PC3-10600' => 1333,
	'PC3-12800' => 1600,
	'PC3-14900 ' => 1866,
	'PC3-17000' => 2133,
	# DDR4
	'PC4-12800' => 1600,
	'PC4-14900' => 1866,
	'PC4-17000' => 2133,
	'PC4-19200' => 2400,
	'PC4-21300' => 2666,
	'PC4-21333' => 2666,
	'PC4-23400' => 2933,
	'PC4-23466' => 2933,
	'PC4-24000' => 3000,
	'PC4-25600' => 3200,
	'PC4-28800' => 3600,
	'PC4-32000' => 4000,
	'PC4-35200' => 4400,
	# DDR5
	'PC5-32000' => 4000,
	'PC5-35200' => 4400,
	'PC5-38400' => 4800,
	'PC5-41600' => 5200,
	'PC5-44800' => 5600,
	'PC5-48000' => 6000,
	'PC5-49600' => 6200,
	'PC5-51200' => 6400,
	'PC5-54400' => 6800,
	'PC5-57600' => 7200,
	'PC5-60800' => 7600,
	'PC5-64000' => 8000,
	# DDR6, coming...
	# 'PC6-xxxxx' => 12800,
	# 'PC6-xxxxx' => 17000, # overclocked
	};
}

# args: 0: pc type string; 
sub speed_mapper {
	eval $start if $b_log;
	set_speed_maps if !$speed_maps;
	eval $end if $b_log;
	return ($speed_maps->{$_[0]}) ?  $speed_maps->{$_[0]} . ' MT/s' : $_[0];
}

## START RAM VENDOR ##
sub set_ram_vendors {
	$vendors = [
	# A-Data xpg: AX4U; AX\d{4} for axiom
	['^(A[DX]\dU|AVD|A[\s-]?Data)','A[\s-]?Data','A-Data',''],
	['^(A[\s-]?Tech)','A[\s-]?Tech','A-Tech',''], # Don't know part nu
	['^(AX[\d]{4}|Axiom)','Axiom','Axiom',''],
	['^(BD\d|Black[s-]?Diamond)','Black[s-]?Diamond','Black Diamond',''],
	['^(-BN$|Brute[s-]?Networks)','Brute[s-]?Networks','Brute Networks',''],
	['^(CM|Corsair)','Corsair','Corsair',''],
	['^(CT\d|BL|Crucial)','Crucial','Crucial',''],
	['^(CY|Cypress)','Cypress','Cypress',''],
	['^(SNP|Dell)','Dell','Dell',''],
	['^(PE[\d]{4}|Edge)','Edge','Edge',''],
	['^(Elpida|EB)','^Elpida','Elpida',''],
	['^(GVT|Galvantech)','Galvantech','Galvantech',''],
	# If we get more G starters, make rules tighter
	['^(G[A-Z]|Geil)','Geil','Geil',''],
	# Note: FA- but make loose FA
	['^(F4|G[\s\.-]?Skill)','G[\s\.-]?Skill','G.Skill',''], 
	['^(GJN)','GJN','GJN',''],
	['^(HP)','','HP',''], # no IDs found
	['^(HX|HyperX)','HyperX','HyperX',''],
	# Qimonda spun out of Infineon, same ids
	# ['^(HYS]|Qimonda)','Qimonda','Qimonda',''],
	['^(HY|Infineon)','Infineon','Infineon',''],#HY[A-Z]\d
	['^(KSM|KVR|Kingston)','Kingston','Kingston',''],
	['^(LuminouTek)','LuminouTek','LuminouTek',''],
	['^(MT|Micron)','Micron','Micron',''],
	# Seen: 992069 991434 997110S
	['^(M[BLERS][A-Z][1-7]|99[0-9]{3}|Mushkin)','Mushkin','Mushkin',''],
	['^(OCZ)','^OCZ\b','OCZ',''],
	['^([MN]D\d|OLOy)','OLOy','OLOy',''],
	['^(M[ERS]\d|Nemix)','Nemix','Nemix',''],
	# Before patriot just in case
	['^(MN\d|PNY)','PNY\s','PNY',''],
	['^(P[A-Z]|Patriot)','Patriot','Patriot',''],
	['^RAMOS','^RAMOS','RAmos',''],
	['^(K[1-6][ABLT]|K\d|M[\d]{3}[A-Z]|Samsung)','Samsung','Samsung',''],
	['^(SP|Silicon[\s-]?Power)','Silicon[\s-]?Power','Silicon Power',''],
	['^(STK|Simtek)','Simtek','Simtek',''],
	['^(Simmtronics|Gamex)','^Simmtronics','Simmtronics',''],
	['^(HM[ACT]|SK[\s-]?Hynix)','SK[\s-]?Hynix','SK-Hynix',''],
	# TED TTZD TLRD TDZAD TF4D4 TPD4 TXKD4 seen: HMT but could by skh
	#['^(T(ED|D[PZ]|F\d|LZ|P[DR]T[CZ]|XK)|Team[\s-]?Group)','Team[\s-]?Group','TeamGroup',''],
	['^(T[^\dR]|Team[\s-]?Group)','Team[\s-]?Group','TeamGroup',''],
	['^(TR\d|JM\d|Transcend)','Transcend','Transcend',''],
	['^(VK\d|Vaseky)','Vaseky','Vaseky',''],
	['^(Yangtze|Zhitai|YMTC)','(Yangtze(\s*Memory)?|YMTC)','YMTC',''],
	];
}

# Note: many of these are pci ids, not confirmed valid for ram
sub set_ram_vendor_ids {
	$vendor_ids = {
	'01f4' => 'Transcend',# confirmed
	'02fe' => 'Elpida',# confirmed
	'0314' => 'Mushkin',# confirmed
	'0420' => 'Chips and Technologies',
	'1014' => 'IBM',
	'1099' => 'Samsung',
	'10c3' => 'Samsung',
	'11e2' => 'Samsung',
	'1249' => 'Samsung',
	'144d' => 'Samsung',
	'15d1' => 'Infineon',
	'167d' => 'Samsung',
	'196e' => 'PNY',
	'1b1c' => 'Corsair',
	'1b85' => 'OCZ',
	'1c5c' => 'SK-Hynix',
	'1cc1' => 'A-Data',
	'1e49' => 'YMTC',# Yangtze Memory confirmed
	'0215' => 'Corsair',# confirmed
	'2646' => 'Kingston',
	'2c00' => 'Micron',# confirmed
	'5105' => 'Qimonda',# confirmed
	'802c' => 'Micron',# confirmed
	'80ad' => 'SK-Hynix',# confirmed
	'80ce' => 'Samsung',# confirmed
	'8551' => 'Qimonda',# confirmed
	'8564' => 'Transcend',
	'859b' => 'Crucial', # confirmed
	'ad00' => 'SK-Hynix',# confirmed
	'c0a9' => 'Crucial',
	'ce00' => 'Samsung',# confirmed
	# '' => '',
	}
}
## END RAM VENDOR ##

sub ram_vendor {
	eval $start if $b_log;
	my ($id) = $_[0];
	set_ram_vendors() if !$vendors;
	my ($vendor);
	foreach my $row (@$vendors){
		if ($id =~ /$row->[0]/i){
			$vendor = $row->[2];
			# Usually we want to assign N/A at output phase, maybe do this logic there?
			if ($row->[1]){
				if ($id !~ m/$row->[1]$/i){
					$id =~ s/$row->[1]//i;
				}
				else {
					$id = 'N/A';
				}
			}
			$id =~ s/^[\/\[\s_-]+|[\/\s_-]+$//g;
			$id =~ s/\s\s/ /g;
			last;
		}
	}
	eval $end if $b_log;
	return [$vendor,$id];
}
}

## RepoItem
{