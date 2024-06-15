package BluetoothItem;
my ($b_bluetooth,$b_hci_error,$b_hci,$b_rfk,$b_service);
my ($service);
my (%hci);

sub get {
	eval $start if $b_log;
	my $rows = [];
	my $num = 0;
	if ($fake{'bluetooth'} || (@ps_cmd && (grep {m|/bluetoothd\b|} @ps_cmd))){
		$b_bluetooth = 1;
	}
	# note: rapi 4 has pci bus
	if (%risc && !$use{'soc-bluetooth'} && !$use{'pci-tool'}){
		# do nothing, but keep the test conditions to force 
		# the non risc case to always run
		# my $key = 'Message';
		# @$rows = ({
		# main::key($num++,0,1,$key) => main::message('risc-pci',$risc{'id'})
		# });
	}
	else {
		device_output($rows);
	}
	usb_output($rows);
	if (!@$rows){
		if ($show{'bluetooth-forced'}){
			my $key = 'Message';
			@$rows = ({main::key($num++,0,1,$key) => main::message('bluetooth-data')});
		}
	}
	# if there are any unhandled hci items print them out
	if (%hci){
		advanced_output($rows,'check','');
	}
	eval $end if $b_log;
	return $rows;
}

sub device_output {
	eval $start if $b_log;
	return if !$devices{'bluetooth'};
	my $rows = $_[0];
	my ($bus_id);
	my ($j,$num) = (0,1);
	foreach my $row (@{$devices{'bluetooth'}}){
		$num = 1;
		$bus_id = '';
		$j = scalar @$rows;
		my $driver = ($row->[9]) ? $row->[9] : 'N/A';
		my $device = $row->[4];
		$device = ($device) ? main::clean_pci($device,'output') : 'N/A';
		# have seen absurdly verbose card descriptions, with non related data etc
		if (length($device) > 85 || $size{'max-cols'} < 110){
			$device = main::filter_pci_long($device);
		}
		push(@$rows, {
		main::key($num++,1,1,'Device') => $device,
		},);
		if ($extra > 0 && $use{'pci-tool'} && $row->[12]){
			my $item = main::get_pci_vendor($row->[4],$row->[12]);
			$rows->[$j]{main::key($num++,0,2,'vendor')} = $item if $item;
		}
		$rows->[$j]{main::key($num++,1,2,'driver')} = $driver;
		if ($extra > 0 && $row->[9] && !$bsd_type){
			my $version = main::get_module_version($row->[9]);
			$rows->[$j]{main::key($num++,0,3,'v')} = $version if $version;
		}
		if ($b_admin && $row->[10]){
			$row->[10] = main::get_driver_modules($row->[9],$row->[10]);
			$rows->[$j]{main::key($num++,0,3,'alternate')} = $row->[10] if $row->[10];
		}
		if ($extra > 0){
			$bus_id = (!$row->[2] && !$row->[3]) ? 'N/A' : "$row->[2].$row->[3]";
			if ($extra > 1 && $bus_id ne 'N/A'){
				main::get_pcie_data($bus_id,$j,$rows,\$num);
			}
			$rows->[$j]{main::key($num++,0,2,'bus-ID')} = $bus_id;
		}
		if ($extra > 1){
			my $chip_id = main::get_chip_id($row->[5],$row->[6]);
			$rows->[$j]{main::key($num++,0,2,'chip-ID')} = $chip_id;
			if ($extra > 2 && $row->[1]){
				$rows->[$j]{main::key($num++,0,2,'class-ID')} = $row->[1];
			}
		}
		# weird serial rpi bt
		if ($use{'soc-bluetooth'}){
			# /sys/devices/platform/soc/fe201000.serial/
			$bus_id = "$row->[6].$row->[1]" if defined $row->[1] && defined $row->[6];
		}
		else {
			# only theoretical, never seen one
			$bus_id = "$row->[2].$row->[3]" if defined $row->[2] && defined $row->[3];
		}
		advanced_output($rows,'pci',$bus_id) if $bus_id;
		# print "$row->[0]\n";
	}
	eval $end if $b_log;
}

sub usb_output {
	eval $start if $b_log;
	return if !$usb{'bluetooth'};
	my $rows = $_[0];
	my ($path_id,$product);
	my ($j,$num) = (0,1);
	foreach my $row (@{$usb{'bluetooth'}}){
		# print Data::Dumper::Dumper $row;
		$num = 1;
		$j = scalar @$rows;
		# makre sure to reset, or second device trips last flag
		($path_id,$product) = ('','');
		$product = main::clean($row->[13]) if $row->[13];
		$product ||= 'N/A';
		$row->[15] ||= 'N/A';
		$path_id = $row->[2] if $row->[2];
		push(@$rows, {
		main::key($num++,1,1,'Device') => $product,
		main::key($num++,1,2,'driver') => $row->[15],
		},);
		if ($extra > 0 && $row->[15] && !$bsd_type){
			my $version = main::get_module_version($row->[15]);
			$rows->[$j]{main::key($num++,0,3,'v')} = $version if $version;
		}
		$rows->[$j]{main::key($num++,1,2,'type')} = 'USB';
		if ($extra > 0){
			if ($extra > 1){
				$row->[8] ||= 'N/A';
				$rows->[$j]{main::key($num++,0,3,'rev')} = $row->[8];
				if ($row->[17]){
					$rows->[$j]{main::key($num++,0,3,'speed')} = $row->[17];
				}
				if ($row->[24]){
					$rows->[$j]{main::key($num++,0,3,'lanes')} = $row->[24];
				}
				if ($b_admin && $row->[22]){
					$rows->[$j]{main::key($num++,0,3,'mode')} = $row->[22];
				}
			}
			$rows->[$j]{main::key($num++,0,2,'bus-ID')} = "$path_id:$row->[1]";
			if ($extra > 1){
				$row->[7] ||= 'N/A';
				$rows->[$j]{main::key($num++,0,2,'chip-ID')} = $row->[7];
			}
			if ($extra > 2){
				if (defined $row->[5] && $row->[5] ne ''){
					$rows->[$j]{main::key($num++,0,2,'class-ID')} = "$row->[4]$row->[5]";
				}
				if ($row->[16]){
					$rows->[$j]{main::key($num++,0,2,'serial')} = main::filter($row->[16]);
				}
			}
		}
		advanced_output($rows,'usb',$path_id) if $path_id;
	}
	eval $end if $b_log;
}

sub advanced_output {
	eval $start if $b_log;
	my ($rows,$type,$bus_id) = @_;
	my (@temp);
	my ($j,$num,$k,$l,$m,$n,$address,$id,$note,$tool) = (0,1,2,3,4,5,'','','','');
	set_bluetooth_data(\$tool);
	# print "bid: $bus_id\n";
	if ($type ne 'check'){
		@temp = main::globber('/sys/class/bluetooth/*');
		@temp = map {$_ = Cwd::abs_path($_);$_} @temp if @temp;
		# print Data::Dumper::Dumper \@temp;
		@temp = grep {/$bus_id/} @temp if @temp;
		@temp = map {$_ =~ s|^/.*/||;$_;} @temp if @temp;
		# print Data::Dumper::Dumper \@temp;
	}
	elsif ($type eq 'check' && %hci){
		@temp = keys %hci;
		$id = '-ID';
		($k,$l,$m,$n) = (1,2,3,4);
	}
	if (@temp && %hci){
		if ($hci{'alert'}){
			if (keys %hci == 1){
				check_service(); # sets $service
				$j = scalar @$rows;
				$rows->[$j]{main::key($num++,1,$k,'Report')} = $tool;
				$rows->[$j]{main::key($num++,0,$l,'bt-service')} = $service;
				$rows->[$j]{main::key($num++,0,$l,'note')} = $hci{'alert'};
			}
			else {
				$note = $hci{'alert'};
			}
			delete $hci{'alert'};
		}
		foreach my $item (@temp){
			if ($hci{$item}){
				$j = scalar @$rows;
				push(@$rows,{
				main::key($num++,1,$k,'Report' . $id) => $tool,
				},);
				if ($note){
					$rows->[$j]{main::key($num++,0,$l,'note')} = $note;
				}
				# synthesize for rfkill
				if (!$hci{$item}->{'state'}){
					$hci{$item}->{'state'} = ($b_bluetooth) ? 'up' : 'down';
				}
				$rows->[$j]{main::key($num++,0,$l,'ID')} = $item;
				if (defined $hci{$item}->{'rf-index'} && 
				 ($extra > 0 || $hci{$item}->{'state'} eq 'down')){
					$rows->[$j]{main::key($num++,0,$m,'rfk-id')} = $hci{$item}->{'rf-index'};
				}
				$rows->[$j]{main::key($num++,1,$l,'state')} = $hci{$item}->{'state'};
				# this only appears for hciconfig, bt-adapter does not run without bt service
				if (!$b_bluetooth || $hci{$item}->{'state'} eq 'down'){
					if (!$b_bluetooth || $hci{$item}->{'state'} eq 'down'){
						check_service(); # sets $service
						$rows->[$j]{main::key($num++,0,$m,'bt-service')} = $service;
					}
					if ($hci{$item}->{'hard-blocked'}){
						$rows->[$j]{main::key($num++,1,$m,'rfk-block')} = '';
						$rows->[$j]{main::key($num++,0,$n,'hardware')} = $hci{$item}->{'hard-blocked'};
						$rows->[$j]{main::key($num++,0,$n,'software')} = $hci{$item}->{'soft-blocked'};
					}
				}
				if (!$hci{$item}->{'address'} && $tool eq 'rfkill'){
					$address = main::message('recommends');
				}
				else {
					$address = main::filter($hci{$item}->{'address'});
				}
				$rows->[$j]{main::key($num++,0,$l,'address')} = $address;
				# lmp/hci version only hciconfig
				if ($hci{$item}->{'bt-version'}){
					$rows->[$j]{main::key($num++,0,$l,'bt-v')} = $hci{$item}->{'bt-version'};
				}
				if ($extra > 0 && defined $hci{$item}->{'lmp-version'}){
					$rows->[$j]{main::key($num++,0,$l,'lmp-v')} = $hci{$item}->{'lmp-version'};
					if ($extra > 1 && $hci{$item}->{'lmp-subversion'}){
						$rows->[$j]{main::key($num++,0,$m,'sub-v')} = $hci{$item}->{'lmp-subversion'};
					}
				}
				if ($extra > 0 && defined $hci{$item}->{'hci-version'} && 
				($extra > 2 || !$hci{$item}->{'lmp-version'} || 
				($hci{$item}->{'lmp-version'} && 
				$hci{$item}->{'lmp-version'} ne $hci{$item}->{'hci-version'}))){
					$rows->[$j]{main::key($num++,0,$l,'hci-v')} = $hci{$item}->{'hci-version'};
					if ($extra > 1 && $hci{$item}->{'hci-revision'}){
						$rows->[$j]{main::key($num++,0,$m,'rev')} = $hci{$item}->{'hci-revision'};
					}
				}
				if ($b_admin && 
				($hci{$item}->{'discoverable'} || $hci{$item}->{'pairable'})){
					$rows->[$j]{main::key($num++,1,$l,'status')} = '';
					if ($hci{$item}->{'discoverable'}){
						$rows->[$j]{main::key($num++,1,$m,'discoverable')} = $hci{$item}->{'discoverable'};
						if ($hci{$item}->{'discovering'}){
							$rows->[$j]{main::key($num++,1,$n,'active')} = $hci{$item}->{'discovering'};
						}
					}
					if ($hci{$item}->{'pairable'}){
						$rows->[$j]{main::key($num++,0,$m,'pairing')} = $hci{$item}->{'pairable'};
					}
				}
				if ($extra > 2 && $hci{$item}->{'class'}){
					$rows->[$j]{main::key($num++,0,$l,'class-ID')} = $hci{$item}->{'class'};
				}
				# this data only from hciconfig
				if ($b_admin && ($hci{$item}->{'acl-mtu'} || $hci{$item}->{'sco-mtu'} || 
				$hci{$item}->{'link-policy'})){
					$j = scalar @$rows;
					push(@$rows,{
					main::key($num++,1,$l,'Info') => '',
					},);
					if ($hci{$item}->{'acl-mtu'}){
						$rows->[$j]{main::key($num++,0,$m,'acl-mtu')} = $hci{$item}->{'acl-mtu'};
					}
					if ($hci{$item}->{'sco-mtu'}){
						$rows->[$j]{main::key($num++,0,$m,'sco-mtu')} = $hci{$item}->{'sco-mtu'};
					}
					if ($hci{$item}->{'link-policy'}){
						$rows->[$j]{main::key($num++,0,$m,'link-policy')} = $hci{$item}->{'link-policy'};
					}
					if ($hci{$item}->{'link-mode'}){
						$rows->[$j]{main::key($num++,0,$m,'link-mode')} = $hci{$item}->{'link-mode'};
					}
					if ($hci{$item}->{'service-classes'}){
						$rows->[$j]{main::key($num++,0,$m,'service-classes')} = $hci{$item}->{'service-classes'};
					}
				}
				delete $hci{$item};
			}
		}
	}
	# since $rows is ref, we need to just check if no $j were set.
	if (!$j && !$b_hci_error && ($alerts{'hciconfig'}->{'action'} ne 'use' &&
	$alerts{'bt-adapter'}->{'action'} ne 'use' && 
	$alerts{'btmgmt'}->{'action'} ne 'use')){
		my $key = 'Report';
		my $value = '';
		if ($alerts{'hciconfig'}->{'action'} eq 'platform' || 
		$alerts{'bt-adapter'}->{'action'} eq 'platform' ||
		$alerts{'btmgmt'}->{'action'} eq 'platform'){
			$value = main::message('tool-missing-os','bluetooth');
		}
		else {
			$value = main::message('tools-missing','hciconfig/bt-adapter');
		}
		push(@$rows,{
		main::key($num++,0,1,$key) => $value,
		},);
		$b_hci_error = 1;
	}
	eval $end if $b_log;
}

# note: echo 'show' | bluetoothctl outputs everything but hciX ID, and is fast
# args: 0: $tool, by ref
sub set_bluetooth_data {
	eval $start if $b_log;
	if (!$b_hci && !$force{'bt-adapter'} && !$force{'btmgmt'} && 
	!$force{'rfkill'} && 
	($fake{'bluetooth'} || $alerts{'hciconfig'}->{'action'} eq 'use')){
		hciconfig_data();
		${$_[0]} = 'hciconfig';
	}
	elsif (!$b_hci && !$force{'rfkill'} && !$force{'bt-adapter'} && 
	($fake{'bluetooth'} || $alerts{'btmgmt'}->{'action'} eq 'use')){
		btmgmt_data();
		${$_[0]} = 'btmgmt';
	}
	elsif (!$b_hci && !$force{'rfkill'} && 
	($fake{'bluetooth'} || $alerts{'bt-adapter'}->{'action'} eq 'use')){
		bt_adapter_data();
		${$_[0]} = 'bt-adapter';
	}
	if (!$b_rfk && ($fake{'bluetooth'} || -e '/sys/class/bluetooth/')){
		rfkill_data();
		${$_[0]} = 'rfkill' if !${$_[0]};
	}
	eval $end if $b_log;
}

sub bt_adapter_data {
	eval $start if $b_log;
	$b_hci = 1;
	my (@data,$id);
	if ($fake{'bluetooth'}){
		my $file;
		$file = "";
		@data = main::reader($file,'strip');
	}
	else {
		if ($b_bluetooth){
			my $cmd = "$alerts{'bt-adapter'}->{'path'} --info 2>/dev/null";
			@data = main::grabber($cmd,'','strip'); 
		}
	}
	# print Data::Dumper::Dumper \@data;
	main::log_data('dump','@data', \@data) if $b_log;
	foreach (@data){
		my @working = split(/:\s*/,$_);
		# print Data::Dumper::Dumper \@working;
		next if ! @working;
		if ($working[0] =~ /^\[([^\]]+)\]/){
			$id = $1;
		}
		elsif ($working[0] eq 'Address'){
			$hci{$id}->{'address'} = join(':',@working[1 .. $#working]);
		}
		elsif ($working[0] eq 'Class' && $working[1] =~ /^0x0*(\S+)/){
			$hci{$id}->{'class'} = $1;
		}
		elsif ($working[0] eq 'Powered'){
			$hci{$id}->{'state'} = ($working[1] =~ /^(1|yes)\b/) ? 'up': 'down';
		}
		elsif ($working[0] eq 'Discoverable'){
			$hci{$id}->{'discoverable'} = ($working[1] =~ /^(1|yes)\b/) ? 'yes': 'no';
		}
		elsif ($working[0] eq 'Pairable'){
			$hci{$id}->{'pairable'} = ($working[1] =~ /^(1|yes)\b/) ? 'yes': 'no';
		}
		elsif ($working[0] eq 'Discovering'){
			$hci{$id}->{'discovering'} = ($working[1] =~ /^(1|yes)\b/) ? 'yes': 'no';
		}
	}
	if (!@data && !$b_bluetooth){
		$hci{'alert'} = main::message('bluetooth-down');
	}
	print 'bt-adapter: ', Data::Dumper::Dumper \%hci if $dbg[27];
	main::log_data('dump','%hci', \%hci) if $b_log;
	eval $end if $b_log;
}

sub btmgmt_data {
	eval $start if $b_log;
	$b_hci = 1;
	my (@data,$id);
	if ($fake{'bluetooth'}){
		my $file;
		$file = "$fake_data_dir/bluetooth/btmgmt-2.txt";
		@data = main::reader($file,'strip');
	}
	else {
		if ($b_bluetooth){
			my $cmd = "$alerts{'btmgmt'}->{'path'} info 2>/dev/null";
			@data = main::grabber($cmd,'', 'strip');
		}
	}
	# print Data::Dumper::Dumper \@data;
	main::log_data('dump','@data', \@data) if $b_log;
	foreach (@data){
		next if /^Index list/;
		if (/^(hci[0-9]+):\s+/){
			$id = $1;
		}
		# addr 4C:F3:72:9C:B4:D3 version 6 manufacturer 15 class 0x000104
		elsif (/^addr\s+([0-9A-F:]+)\s+version\s+([0-9]+)\s/){
			$hci{$id}->{'address'} = $1;
			$hci{$id}->{'lmp-version'} = $2; # assume non hex integer
			$hci{$id}->{'bt-version'} = bluetooth_version($2);
			if (/ class\s+0x0*(\S+)\b/){
				$hci{$id}->{'class'} = $1;
			}
		}
		elsif (/^current settings:\s+(.*)/){
			my $settings = $1;
			$hci{$id}->{'state'} = ($settings =~ /\bpowered\b/) ? 'up' : 'down';
			$hci{$id}->{'discoverable'} = ($settings =~ /\bdiscoverable\b/) ? 'yes' : 'no';
			$hci{$id}->{'pairable'} = ($settings =~ /\bconnectable\b/) ? 'yes' : 'no';
		}
	}
	print 'btmgmt: ', Data::Dumper::Dumper \%hci if $dbg[27];
	main::log_data('dump','%hci', \%hci) if $b_log;
	eval $end if $b_log;
}

sub hciconfig_data {
	eval $start if $b_log;
	$b_hci = 1;
	my (@data,$id);
	if ($fake{'bluetooth'}){
		my $file;
		$file = "$fake_data_dir/bluetooth/hciconfig-a-2.txt";
		@data = main::reader($file,'strip');
	}
	else {
		my $cmd = "$alerts{'hciconfig'}->{'path'} -a 2>/dev/null";
		@data = main::grabber($cmd,'', 'strip');
	}
	# print Data::Dumper::Dumper \@data;
	main::log_data('dump','@data', \@data) if $b_log;
	foreach (@data){
		if (/^(hci[0-9]+):\s+Type:\s+(.*)\s+Bus:\s+([\S]+)/){
			$id = $1;
			$hci{$id} = {
			'type'=> $2,
			'bus' => $3,
			};
		}
		elsif (/^BD Address:\s+([0-9A-F:]*)\s+ACL\s+MTU:\s+([0-9:]+)\s+SCO MTU:\s+([0-9:]+)/){
			$hci{$id}->{'address'} = $1;
			$hci{$id}->{'acl-mtu'} = $2;
			$hci{$id}->{'sco-mtu'} = $3;
		}
		elsif (/^(UP|DOWN).*/){
			$hci{$id}->{'state'} = lc($1);
		}
		elsif (/^Class:\s+0x0*(\S+)/){
			$hci{$id}->{'class'} = $1;
		}
		# HCI Version: 4.0 (0x6)  Revision: 0x1000
		# HCI Version: 6.6  Revision: 0x1000 [don't know if this exists]
		# HCI Version:  (0x7)  Revision: 0x3101
		elsif (/^HCI Version:\s+(([0-9\.]+)\s+)?\(0x([0-9a-f]+)\)\s+Revision:\s+0x([0-9a-f]+)/i){
			$hci{$id}->{'hci-revision'} = $4;
			if (defined $3){
				$hci{$id}->{'bt-version'} = bluetooth_version(hex($3));
				$hci{$id}->{'hci-version'} = hex($3);
				$hci{$id}->{'hci-version-hex'} = $3;
			}
		}
		# LMP Version: 4.0 (0x6)  Subversion: 0x220e
		# LMP Version: 6.6  Revision: 0x1000 [don't know if this exists]
		# LMP Version:  (0x7)  Subversion: 0x1
		elsif (/^LMP Version:\s+(([0-9\.]+)\s+)?\(0x([0-9a-f]+)\)\s+Subversion:\s+0x([0-9a-f]+)/i){
			$hci{$id}->{'lmp-subversion'} = $4;
			$hci{$id}->{'bt-version'} = bluetooth_version(hex($3));
			$hci{$id}->{'lmp-version'} = hex($3);
			$hci{$id}->{'lmp-version-hex'} = $3;
		}
		elsif (/^Link policy:\s+(.*)/){
			$hci{$id}->{'link-policy'} = lc($1);
		}
		elsif (/^Link mode:\s+(.*)/){
			$hci{$id}->{'link-mode'} = lc($1);
		}
		elsif (/^Service Classes?:\s+(.+)/){
			$hci{$id}->{'service-classes'} = main::clean_unset(lc($1));
		}
	}
	print 'hciconfig: ', Data::Dumper::Dumper \%hci if $dbg[27];
	main::log_data('dump','%hci', \%hci) if $b_log;
	eval $end if $b_log;
}

sub rfkill_data {
	eval $start if $b_log;
	$b_rfk = 1;
	my (@data,$id,$value);
	if ($fake{'bluetooth'}){
		my $file;
		$file = "";
		@data = main::reader($file,'strip');
	}
	else {
		# /state is the state of rfkill, NOT bluetooth!
		@data = main::globber('/sys/class/bluetooth/hci*/rfkill*/{hard,index,soft}');
	}
	# print Data::Dumper::Dumper \@data;
	main::log_data('dump','@data', \@data) if $b_log;
	foreach (@data){
		$id = (split(/\//,$_))[4];
		if (m|/soft$|){
			$value = main::reader($_,'strip',0);
			$hci{$id}->{'soft-blocked'} = ($value) ? 'yes': 'no';
			$hci{$id}->{'state'} = 'down' if $hci{$id}->{'soft-blocked'} eq 'yes';
		}
		elsif (m|/hard$|){
			$value = main::reader($_,'strip',0);
			$hci{$id}->{'hard-blocked'} = ($value) ? 'yes': 'no';
			$hci{$id}->{'state'} = 'down' if $hci{$id}->{'hard-blocked'} eq 'yes';
		}
		elsif (m|/index$|){
			$value = main::reader($_,'strip',0);
			$hci{$id}->{'rf-index'} = $value;
		}
	}
	print 'rfkill: ', Data::Dumper::Dumper \%hci if $dbg[27];
	main::log_data('dump','%hci', \%hci) if $b_log;
	eval $end if $b_log;
}

sub check_service {
	eval $start if $b_log;
	if (!$b_service){
		$service = ServiceData::get('status','bluetooth');
		$service ||= 'N/A';
		$b_service = 1;
	}
	eval $end if $b_log;
}

# args: 0: lmp versoin - could be hex, but probably decimal, like 6.6
sub bluetooth_version {
	eval $start if $b_log;
	my ($lmp) = @_;
	return if !defined $lmp;
	return if !main::is_numeric($lmp);
	$lmp = int($lmp);
	# Conveniently, LMP starts with 0, so perfect for array indexes.
	# 6.0 is coming, but might be 5.5 first, nobody knows.
	my @bt = qw(1.0b 1.1 1.2 2.0 2.1 3.0 4.0 4.1 4.2 5.0 5.1 5.2 5.3 5.4);
	return $bt[$lmp];
	eval $end if $b_log;
}
}

## CpuItem
{