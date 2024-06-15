package UsbData;
my (@working);
my (@asound_ids,$b_asound,$b_hub,$addr_id,$bus_id,$bus_id_alpha,
$chip_id,$class_id,$device_id,$driver,$driver_nu,$ids,$interfaces,
$name,$network_regex,$path,$path_id,$power,$product,$product_id,$protocol_id,
$mode,$rev,$serial,$speed_si,$speed_iec,$subclass_id,$type,$version,
$vendor,$vendor_id);
my $b_live = 1; # debugger file data

sub set {
	eval $start if $b_log;
	${$_[0]} = 1; # set checked boolean
	# note: bsd package usbutils has lsusb in it, but we dont' want it for default
	# usbdevs is best, has most data, and runs as user
	if ($alerts{'usbdevs'}->{'action'} eq 'use'){
		usbdevs_data();
	}
	# usbconfig has weak/poor output, and requires root, only fallback
	elsif ($alerts{'usbconfig'}->{'action'} eq 'use'){
		usbconfig_data();
	}
	# if user config sets USB_SYS you can override with --usb-tool
	elsif ((!$force{'usb-sys'} || $force{'lsusb'}) && $alerts{'lsusb'}->{'action'} eq 'use'){
		lsusb_data();
	}
	elsif (-d '/sys/bus/usb/devices'){
		sys_data('main');
	}
	@{$usb{'main'}} = sort {$a->[0] cmp $b->[0]} @{$usb{'main'}} if $usb{'main'};
	if ($b_log){
		main::log_data('dump','$usb{audio}: ',$usb{'audio'});
		main::log_data('dump','$usb{bluetooth}: ',$usb{'bluetooth'});
		main::log_data('dump','$usb{disk}: ',$usb{'disk'});
		main::log_data('dump','$usb{graphics}: ',$usb{'graphics'});
		main::log_data('dump','$usb{network}: ',$usb{'network'});
	}
	if ($dbg[55]){
		print '$usb{audio}: ', Data::Dumper::Dumper $usb{'audio'};
		print '$usb{bluetooth}: ', Data::Dumper::Dumper $usb{'bluetooth'};
		print '$usb{disk}: ', Data::Dumper::Dumper $usb{'disk'};
		print '$usb{graphics}: ', Data::Dumper::Dumper $usb{'graphics'};
		print '$usb{network}: ', Data::Dumper::Dumper $usb{'network'};
	}
	eval $end if $b_log;
}

sub lsusb_data {
	eval $start if $b_log;
	my (@temp);
	my @data = usb_grabber('lsusb');
	foreach (@data){
		next if /^~$|^Couldn't/; # expensive second call: || /UNAVAIL/
		@working = split(/\s+/, $_);
		next unless defined $working[1] && defined $working[3];
		$working[3] =~ s/:$//;
		# Don't use this fix, the data is garbage in general! Seen FreeBSD lsusb with: 
		# Bus /dev/usb Device /dev/ugen0.3: ID 24ae:1003 Shenzhen Rapoo Technology Co., Ltd. 
		# hub, note incomplete data: Bus /dev/usb Device /dev/ugen0.1: ID 0000:0000 
		# linux: 
		# Bus 005 Device 007: ID 0d8c:000c C-Media Electronics, Inc. Audio Adapter
		# if ($working[3] =~ m|^/dev/ugen([0-9]+)\.([0-9]+)|){
		#	$working[1] = $1;
		#	$working[3] = $2;
		# }
		next unless main::is_numeric($working[1]) && main::is_numeric($working[3]);
		$addr_id = int($working[3]);
		$bus_id = int($working[1]);
		$path_id = "$bus_id-$addr_id";
		$chip_id = $working[5];
		@temp = @working[6..$#working];
		$name = main::remove_duplicates(join(' ', @temp));
		# $type = check_type($name,'','');
		$type ||= '';
		# do NOT set bus_id_alpha here!!
		# print "$name\n";
		$working[0] = $bus_id;
		$working[1] = $addr_id;
		$working[2] = $path_id;
		$working[3] = '';
		$working[4] = '00';
		$working[5] = '';
		$working[6] = '';
		$working[7] = $chip_id;
		$working[8] = '';
		$working[9] = '';
		$working[10] = 0;
		$working[11] = '';
		$working[12] = '';
		$working[13] = $name;
		$working[14] = '';# $type;
		$working[15] = '';
		$working[16] = '';
		$working[17] = '';
		$working[18] = '';
		$working[19] = '';
		$working[20] = '';
		push(@{$usb{'main'}},[@working]);
		# print join("\n",@working),"\n\n=====\n";
	}
	print 'lsusb-pre-sys: ', Data::Dumper::Dumper $usb{'main'} if $dbg[6];
	sys_data('lsusb') if $usb{'main'};
	print 'lsusb-w-sys: ', Data::Dumper::Dumper $usb{'main'} if $dbg[6];
	main::log_data('dump','$usb{main}: plain',$usb{'main'}) if $b_log;
	eval $end if $b_log;
}

# ugen0.1: <Apple OHCI root HUB> at usbus0, cfg=0 md=HOST spd=FULL (12Mbps) pwr=SAVE (0mA)
# ugen0.2: <MediaTek 802.11 n WLAN> at usbus0, cfg=0 md=HOST spd=FULL (12Mbps) pwr=ON (160mA)
# note: tried getting driver/ports from dmesg, impossible, waste of time
sub usbconfig_data {
	eval $start if $b_log;
	my ($cfg,$hub_id,$ports);
	my @data = usb_grabber('usbconfig');
	foreach (@data){
		if ($_ eq '~' && @working){
			$chip_id = ($vendor_id || $product_id) ? "$vendor_id:$product_id" : '';
			$working[7] = $chip_id;
			$product ||= '';
			$vendor ||= '';
			$working[13] = main::remove_duplicates("$vendor $product") if $product || $vendor;
			# leave the ugly vendor/product ids unless chip-ID shows!
			$working[13] = $chip_id if $extra < 2 && $chip_id && !$working[13];
			if (defined $class_id && defined $subclass_id && defined $protocol_id){
				$class_id = hex($class_id);
				$subclass_id = hex($subclass_id);
				$protocol_id = hex($protocol_id);
				$type = device_type("$class_id/$subclass_id/$protocol_id");
			}
			if ($working[13] && (!$type || $type eq '<vendor defined>')){
				$type = check_type($working[13],'','');
			}
			$working[14] = $type;
			push(@{$usb{'main'}},[@working]);
			assign_usb_type([@working]);
			undef @working;
		}
		elsif (/^([a-z_-]+)([0-9]+)\.([0-9]+):\s+<[^>]+>\s+at usbus([0-9]+)\b/){
			($class_id,$cfg,$power,$rev,$mode,$speed_si,$speed_iec,$subclass_id,
			$type) = ();
			($product,$product_id,$vendor,$vendor_id) = ('','','','');
			$hub_id = $2;
			$addr_id = $3;
			$bus_id = $4;
			$path_id = "$bus_id-$hub_id.$addr_id";
			$bus_id_alpha = bus_id_alpha($path_id);
			if (/\bcfg\s*=\s*([0-9]+)/){
				$cfg = $1;
			}
			if (/\bmd\s*=\s*([\S]+)/){
				# nothing
			}
			# odd, using \b after ) doesn't work as expected
			# note that bsd spd=FULL has no interest since we get that from the speed
			if (/\b(speed|spd)\s*=\s*([\S]+)\s+\(([^\)]+)\)/){
				$speed_si = $3;
			}
			if (/\b(power|pwr)\s*=\s*([\S]+)\s+\(([0-9]+mA)\)/){
				$power = $3;
				process_power(\$power) if $power;
			}
			version_data('bsd',\$speed_si,\$speed_iec,\$rev,\$mode);
			$working[0] = $bus_id_alpha;
			$working[1] = $addr_id;
			$working[2] = $path_id;
			$working[3] = '';
			$working[8] = $rev;
			$working[9] = '';
			$working[10] = $ports;
			$working[15] = $driver;
			$working[17] = $speed_si;
			$working[18] = $cfg;
			$working[19] = $power;
			$working[20] = '';
			$working[21] = $driver_nu;
			$working[22] = $mode;
			$working[25] = $speed_iec;
		}
		elsif (/^bDeviceClass\s*=\s*0x00([a-f0-9]{2})\s*(<([^>]+)>)?/){
			$class_id = $1;
			$working[4] = $class_id;
		}
		elsif (/^bDeviceSubClass\s*=\s*0x00([a-f0-9]{2})/){
			$subclass_id = $1;
			$working[5] = $subclass_id;
		}
		elsif (/^bDeviceProtocol\s*=\s*0x00([a-f0-9]{2})/){
			$protocol_id = $1;
			$working[6] = $protocol_id;
		}
		elsif (/^idVendor\s*=\s*0x([a-f0-9]{4})/){
			$vendor_id = $1;
		}
		elsif (/^idProduct\s*=\s*0x([a-f0-9]{4})/){
			$product_id = $1;
		}
		elsif (/^iManufacturer\s*=\s*0x([a-f0-9]{4})\s*(<([^>]+)>)?/){
			$vendor = main::clean($3);
			$vendor =~ s/^0x.*//; # seen case where vendor string was ID
			$working[11] = $vendor;
		}
		elsif (/^iProduct\s*=\s*0x([a-f0-9]{4})\s*(<([^>]+)>)?/){
			$product = main::clean($3);
			$product =~ s/^0x.*//; # in case they put product ID in, sigh
			$working[12] = $product;
		}
		elsif (/^iSerialNumber\s*=\s*0x([a-f0-9]{4})\s*(<([^>]+)>)?/){
			$working[16] = main::clean($3);
		}
	}
	main::log_data('dump','$usb{main}: usbconfig',$usb{'main'}) if $b_log;
	print 'usbconfig: ', Data::Dumper::Dumper $usb{'main'} if $dbg[6];
	eval $end if $b_log;
}

# Controller /dev/usb2:
# addr 1: full speed, self powered, config 1, UHCI root hub(0x0000), Intel(0x8086), rev 1.00
#  port 1 addr 2: full speed, power 98 mA, config 1, USB Receiver(0xc52b), Logitech(0x046d), rev 12.01
#  port 2 powered
sub usbdevs_data {
	eval $start if $b_log;
	my ($b_multi,$class,$config,$hub_id,$port,$port_value,$product_rev);
	my ($ports) = (0);
	my @data = usb_grabber('usbdevs');
	foreach (@data){
		if ($_ eq '~' && @working){
			$working[10] = $ports;
			push(@{$usb{'main'}},[@working]);
			assign_usb_type([@working]);
			undef @working;
			($config,$driver,$power,$rev) = ('','','','');
		}
		elsif (/^Controller\s\/dev\/usb([0-9]+)/){
			$bus_id = $1;
		}
		elsif (/^addr\s([0-9]+):\s([^,]+),[^,0-9]+([0-9]+ mA)?,\s+config\s+([0-9]+),\s?([^,]+)\(0x([0-9a-f]{4})\),\s?([^,]+)\s?\(0x([0-9a-f]{4})\)/){
			($mode,$rev,$speed_si,$speed_iec) = ();
			$hub_id = $1;
			$addr_id = $1;
			$speed_si = $2; # requires prep
			$power = $3;
			$chip_id = "$6:$8";
			$config = $4;
			$name = main::remove_duplicates("$7 $5");
			# print "p1:$protocol\n";
			$path_id = "$bus_id-$hub_id";
			$bus_id_alpha = bus_id_alpha($path_id);
			$ports = 0;
			process_power(\$power) if $power;
			$port_value = '';
			version_data('bsd',\$speed_si,\$speed_iec,\$rev,\$mode);
			$working[0] = $bus_id_alpha;
			$working[1] = $addr_id;
			$working[2] = $path_id;
			$working[3] = '';
			$working[4] = '09';
			$working[5] = '';
			$working[6] = '';
			$working[7] = $chip_id;
			$working[8] = $rev;
			$working[9] = '';
			$working[10] = $ports;
			$working[13] = $name;
			$working[14] = 'Hub';
			$working[15] = '';
			$working[16] = '';
			$working[17] = $speed_si;
			$working[18] = $config;
			$working[19] = $power;
			$working[20] = '';
			$working[22] = $mode;
			$working[25] = $speed_iec;
		}
		elsif (/^port\s([0-9]+)\saddr\s([0-9]+):\s([^,]+),[^,0-9]*([0-9]+\s?mA)?,\s+config\s+([0-9]+),\s?([^,]+)\(0x([0-9a-f]{4})\),\s?([^,]+)\s?\(0x([0-9a-f]{4})\)/){
			($rev,$mode,$speed_iec,$speed_si) = ();
			$port = $1;
			$addr_id = $2;
			$speed_si = $3;
			$power = $4;
			$config = $5;
			$chip_id = "$7:$9";
			$name = main::remove_duplicates("$8 $6");
			$type = check_type($name,'','');
			$type ||= '';
			# print "p2:$protocol\n";
			$ports++;
			$path_id = "$bus_id-$hub_id.$port";
			$bus_id_alpha = bus_id_alpha($path_id);
			process_power(\$power) if $power;
			version_data('bsd',\$speed_si,\$speed_iec,\$rev,\$mode);
			$working[0] = $bus_id_alpha;
			$working[1] = $addr_id;
			$working[2] = $path_id;
			$working[3] = '';
			$working[4] = '01';
			$working[5] = '';
			$working[6] = '';
			$working[7] = $chip_id;
			$working[8] = $rev;
			$working[9] = '';
			$working[10] = $ports;
			$working[11] = '';
			$working[12] = '';
			$working[13] = $name;
			$working[14] = $type;
			$working[15] = '';
			$working[16] = '';
			$working[17] = $speed_si;
			$working[18] = $config;
			$working[19] = $power;
			$working[20] = '';
			$working[22] = $mode;
			$working[25] = $speed_iec;
		}
		elsif (/^port\s([0-9]+)\spowered/){
			$ports++;
		}
		# newer openbsd usbdevs totally changed their syntax and layout, but it is better...
		elsif (/^addr\s*([0-9a-f]+):\s+([a-f0-9]{4}:[a-f0-9]{4})\s*([^,]+)?(,\s[^,]+?)?,\s+([^,]+)$/){
			$addr_id = $1;
			$chip_id = $2;
			$vendor = main::clean($3) if $3;
			$vendor ||= '';
			$name = main::remove_duplicates("$vendor $5");
			$type = check_type($name,'','');
			$class_id = ($name =~ /hub/i) ? '09': '01';
			$path_id = "$bus_id-$addr_id";
			$bus_id_alpha = bus_id_alpha($path_id);
			$ports = 0;
			$b_multi = 1;
			$working[0] = $bus_id_alpha;
			$working[1] = $addr_id;
			$working[2] = $path_id;
			$working[3] = '';
			$working[4] = $class_id;
			$working[5] = '';
			$working[6] = '';
			$working[7] = $chip_id;
			$working[8] = '';
			$working[9] = '';
			$working[10] = $ports;
			$working[11] = '';
			$working[12] = '';
			$working[13] = $name;
			$working[14] = $type;
			$working[15] = '';
			$working[16] = '';
			$working[17] = '';
			$working[18] = '';
			$working[19] = '';
			$working[20] = '';
		}
		elsif ($b_multi && 
		/^([^,]+),\s+(self powered|power\s+([0-9]+\s+mA)),\s+config\s([0-9]+),\s+rev\s+([0-9\.]+)(,\s+i?Serial\s(\S*))?/i){
			($mode,$rev,$speed_iec,$speed_si) = ();
			$speed_si = $1;
			$power = $3;
			process_power(\$power) if $power;
			version_data('bsd',\$speed_si,\$speed_iec,\$rev,\$mode);
			$working[8] = $rev;
			$working[16] = $7 if $7;
			$working[17] = $speed_si;
			$working[18] = $4; # config number
			$working[19] = $power; 
			$working[20] = $5; # product rev
			$working[22] = $mode;
			$working[25] = $speed_iec;
		}
		# 1 or more drivers supported
		elsif ($b_multi && /^driver:\s*([^,]+)$/){
			my $temp = $1;
			$working[4] = '09' if $temp =~ /hub[0-9]/;
			$temp =~ s/([0-9]+)$//;
			$working[21] = $1; # driver nu
			# drivers, note that when numbers trimmed off, drivers can have same name
			$working[15] = ($working[15] && $working[15] !~ /\b$temp\b/) ? "$working[15],$temp" : $temp; 
			# now that we have the driver, let's recheck the type
			if (!$type && $name && $working[15]){
				$type = check_type($name,$working[15],'');
				$working[14] = $type if $type;
			}
		}
		elsif ($b_multi && /^port\s[0-9]/){
			$ports++;
		}
	}
	main::log_data('dump','$usb{main}: usbdevs',$usb{'main'}) if $b_log;
	print 'usbdevs: ', Data::Dumper::Dumper $usb{'main'} if $dbg[6];
	eval $end if $b_log;
}

sub usb_grabber {
	eval $start if $b_log;
	my ($program) = @_;
	my ($args,$path,$pattern,@data,@working);
	if ($program eq 'lsusb'){
		$args = '';
		$path = $alerts{'lsusb'}->{'path'};
		$pattern = '^Bus [0-9]';
	}
	elsif ($program eq 'usbconfig'){
		$args = 'dump_device_desc';
		$path = $alerts{'usbconfig'}->{'path'};
		$pattern = '^[a-z_-]+[0-9]+\.[0-9]+:';
	}
	elsif ($program eq 'usbdevs'){
		$args = '-vv';
		$path = $alerts{'usbdevs'}->{'path'};
		$pattern = '^(addr\s[0-9a-f]+:|port\s[0-9]+\saddr\s[0-9]+:)';
	}
	if ($b_live && !$fake{'usbdevs'} && !$fake{'usbconfig'}){
		@data = main::grabber("$path $args 2>/dev/null",'','strip');
	}
	else {
		my $file;
		if ($fake{'usbdevs'}){
			$file = "$fake_data_dir/usb/usbdevs/bsd-usbdevs-v-1.txt";
		}
		elsif ($fake{'usbconfig'}){
			$file = "$fake_data_dir/usb/usbconfig/bsd-usbconfig-list-v-1.txt";
		}
		else {
			$file = "$fake_data_dir/usb/lsusb/mdmarmer-lsusb.txt";
		}
		@data = main::reader($file,'strip');
	}
	if (@data){
		$use{'usb-tool'} = 1 if scalar @data > 2;
		foreach (@data){
			# this is the group separator and assign trigger
			push(@working, '~') if $_ =~ /$pattern/i;
			push(@working, $_);
		}
		push(@working, '~');
	}
	print Data::Dumper::Dumper \@working if $dbg[30];
	eval $end if $b_log;
	return @working;
}

sub sys_data {
	eval $start if $b_log;
	my ($source) = @_;
	my ($configuration,$lanes_rx,$lanes_tx,$ports,$mode,$rev); 
	my (@drivers,@uevent);
	my $i = 0;
	my @files = main::globber('/sys/bus/usb/devices/*');
	# we want to get rid of the hubs with x-0: syntax, those are hubs found in /usbx
	@files = grep {!/\/[0-9]+-0:/} @files;
	# print join("\n", @files);
	foreach my $file (@files){
		# be careful, sometimes uevent is not readable
		@uevent = (-r "$file/uevent") ? main::reader("$file/uevent") : undef;
		if (@uevent && ($ids = main::awk(\@uevent,'^(DEVNAME|DEVICE\b)',2,'='))){
			($b_hub,$class_id,$protocol_id,$subclass_id) = (0,0,0,0);
			(@drivers,$lanes_rx,$lanes_tx,$mode,$rev,$speed_iec,$speed_si) = ();
			($configuration,$driver,$interfaces,$name,$ports,$product,$serial,
			$type,$vendor) = ('','','','','','','','','');
			# print Cwd::abs_path($file),"\n";
			# print "f1: $file\n";
			$path_id = $file;
			$path_id =~ s/^.*\///;
			$path_id =~ s/^usb([0-9]+)/$1-0/;
			# if DEVICE= then path = /proc/bus/usb/001/001 else: bus/usb/006/001
			$ids =~ s/^\///;
			@working = split('/', $ids);
			shift @working if $working[0] eq 'proc';
			$bus_id = int($working[2]);
			$bus_id_alpha = bus_id_alpha($path_id);
			$device_id = int($working[3]);
			# this will be a hex number
			$class_id = sys_item("$file/bDeviceClass");
			# $subclass_id = sys_item("$file/bDeviceSubClass");
			# $protocol_id = sys_item("$file/bDeviceProtocol");
			$class_id = hex($class_id) if $class_id;
			# $subclass_id = hex($subclass_id) if $subclass_id;
			# $protocol_id = hex($protocol_id) if $protocol_id;
			# print "$path_id $class_id/$subclass_id/$protocol_id\n";
			$power = sys_item("$file/bMaxPower");
			process_power(\$power) if $power;
			# this populates class, subclass, and protocol id with decimal numbers
			@drivers = uevent_data("$file/[0-9]*/uevent");
			push(@drivers, uevent_data("$file/[0-9]*/*/uevent")) if !$b_hub;
			$ports = sys_item("$file/maxchild") if $b_hub;
			if (@drivers){
				main::uniq(\@drivers);
				$driver = join(',', sort @drivers);
			}
			$interfaces = sys_item("$file/bNumInterfaces");
			$lanes_rx = sys_item("$file/rx_lanes");
			$lanes_tx = sys_item("$file/tx_lanes");
			$serial = sys_item("$file/serial");
			$rev = sys_item("$file/version");
			$speed_si = sys_item("$file/speed");
			version_data('sys',\$speed_si,\$speed_iec,\$rev,\$mode,$lanes_rx,$lanes_tx);
			$configuration = sys_item("$file/configuration");
			$power = sys_item("$file/bMaxPower");
			process_power(\$power) if $power;
			$class_id = sprintf("%02x", $class_id) if defined $class_id && $class_id ne '';
			$subclass_id = sprintf("%02x", $subclass_id) if defined $subclass_id && $subclass_id ne '';
			if ($source eq 'lsusb'){
				for ($i = 0; $i < scalar @{$usb{'main'}}; $i++){
					if ($usb{'main'}->[$i][0] eq $bus_id && $usb{'main'}->[$i][1] == $device_id){
						if (!$b_hub && $usb{'main'}->[$i][13] && (!$type || $type eq '<vendor specific>')){
							$type = check_type($usb{'main'}->[$i][13],$driver,$type);
						}
						$usb{'main'}->[$i][0] = $bus_id_alpha;
						$usb{'main'}->[$i][2] = $path_id;
						$usb{'main'}->[$i][3] = $file;
						$usb{'main'}->[$i][4] = $class_id;
						$usb{'main'}->[$i][5] = $subclass_id;
						$usb{'main'}->[$i][6] = $protocol_id;
						$usb{'main'}->[$i][8] = $rev;
						$usb{'main'}->[$i][9] = $interfaces;
						$usb{'main'}->[$i][10] = $ports if $ports;
						if ($type && $b_hub && (!$usb{'main'}->[$i][13] || 
						$usb{'main'}->[$i][13] =~ /^linux foundation/i)){
							$usb{'main'}->[$i][13] = "$type";
						}
						$usb{'main'}->[$i][14] = $type if ($type && !$b_hub);
						$usb{'main'}->[$i][15] = $driver if $driver;
						$usb{'main'}->[$i][16] = $serial if $serial;
						$usb{'main'}->[$i][17] = $speed_si if $speed_si;
						$usb{'main'}->[$i][18] = $configuration;
						$usb{'main'}->[$i][19] = $power;
						$usb{'main'}->[$i][20] = '';
						$usb{'main'}->[$i][22] = $mode;
						$usb{'main'}->[$i][23] = $lanes_rx;
						$usb{'main'}->[$i][24] = $lanes_tx;
						$usb{'main'}->[$i][25] = $speed_iec if $speed_iec;
						$usb{'main'}->[$i][26] = Cwd::abs_path($file);
						assign_usb_type($usb{'main'}->[$i]);
						# print join("\n",@{$usb{'main'}->[$i]}),"\n\n";# if !$b_hub; 
						last;
					}
				}
			}
			else {
				$chip_id = sys_item("$file/idProduct");
				$vendor_id = sys_item("$file/idVendor");
				# we don't want the device, it's probably a bad path in /sys/bus/usb/devices
				next if !$vendor_id && !$chip_id;
				$product = sys_item("$file/product");
				$product = main::clean($product) if $product;
				$vendor = sys_item("$file/manufacturer");
				$vendor = main::clean($vendor) if $vendor;
				if (!$b_hub && ($product || $vendor)){
					if ($vendor && $product && $product !~ /$vendor/){
						$name = "$vendor $product";
					}
					elsif ($product){
						$name = $product;
					}
					elsif ($vendor){
						$name = $vendor;
					}
				}
				elsif ($b_hub){
					$name = $type;
				}
				$name = main::remove_duplicates($name) if $name;
				if (!$b_hub && $name && (!$type || $type eq '<vendor specific>')){
					$type = check_type($name,$driver,$type);
				}
				# this isn't that useful, but save in case something shows up
				# if ($configuration){
				#	$name = ($name) ? "$name $configuration" : $configuration;
				# }
				$type = 'Hub' if $b_hub;
				$usb{'main'}->[$i][0] = $bus_id_alpha;
				$usb{'main'}->[$i][1] = $device_id;
				$usb{'main'}->[$i][2] = $path_id;
				$usb{'main'}->[$i][3] = $file;
				$usb{'main'}->[$i][4] = $class_id;
				$usb{'main'}->[$i][5] = $subclass_id;
				$usb{'main'}->[$i][6] = $protocol_id;
				$usb{'main'}->[$i][7] = "$vendor_id:$chip_id";
				$usb{'main'}->[$i][8] = $rev;
				$usb{'main'}->[$i][9] = $interfaces;
				$usb{'main'}->[$i][10] = $ports;
				$usb{'main'}->[$i][11] = $vendor;
				$usb{'main'}->[$i][12] = $product;
				$usb{'main'}->[$i][13] = $name;
				$usb{'main'}->[$i][14] = $type;
				$usb{'main'}->[$i][15] = $driver;
				$usb{'main'}->[$i][16] = $serial;
				$usb{'main'}->[$i][17] = $speed_si;
				$usb{'main'}->[$i][18] = $configuration;
				$usb{'main'}->[$i][19] = $power;
				$usb{'main'}->[$i][20] = '';
				$usb{'main'}->[$i][22] = $mode;
				$usb{'main'}->[$i][23] = $lanes_rx;
				$usb{'main'}->[$i][24] = $lanes_tx;
				$usb{'main'}->[$i][25] = $speed_iec;
				$usb{'main'}->[$i][26] = Cwd::abs_path($file);
				assign_usb_type($usb{'main'}->[$i]);
				$i++;
			}
			# print "$path_id ids: $bus_id:$device_id driver: $driver ports: $ports\n==========\n"; # if $dbg[6];;
		}
	}
	print 'usb-sys: ', Data::Dumper::Dumper $usb{'main'} if $source eq 'main' && $dbg[6];
	main::log_data('dump','$usb{main}: sys',$usb{'main'}) if $source eq 'main' && $b_log;
	eval $end if $b_log;
}

# Get driver, interface [type:] data
sub uevent_data {
	my ($path) = @_;
	my ($interface,$interfaces,$temp,@interfaces,@drivers);
	my @files = main::globber($path);
	@files = grep {!/\/(subsystem|driver|ep_[^\/]+)\/uevent$/} @files if @files;
	foreach (@files){
		last if $b_hub;
		# print "f2: $_\n";
		($interface) = ('');
		@working = main::reader($_) if -r $_;
		# print join("\n",@working), "\n";
		if (@working){
			$driver = main::awk(\@working,'^DRIVER',2,'=');
			$interface = main::awk(\@working,'^INTERFACE',2,'='); 
			if ($interface){
				# for hubs, we need the specific protocol, which is in TYPE
				if ($interface eq '9/0/0' && 
				 (my $temp = main::awk(\@working,'^TYPE',2,'='))){
					$interface = $temp; 
				}
				# print "$interface\n";
				$interface = device_type($interface);
				if ($interface){
					if ($interface ne '<vendor specific>'){
						push(@interfaces, $interface);
					}
					# networking requires more data but this test is reliable
					elsif (!@interfaces){
						$temp = $_;
						$temp =~ s/\/uevent$//;
						push(@interfaces, 'Network') if -d "$temp/net/";
					}
					if (!@interfaces){
						push(@interfaces, $interface);
					}
				}
			}
		}
		# print "driver:$driver\n";
		$b_hub = 1 if $driver && $driver eq 'hub';
		$driver = '' if $driver && ($driver eq 'usb' || $driver eq 'hub');
		push(@drivers,$driver) if $driver;
	}
	if (@interfaces){
		main::uniq(\@interfaces);
		# clear out values like: <vendor specific>,Printer
		if (scalar @interfaces > 1 && (grep {!/^<vendor/} @interfaces) && (grep {/^<vendor/} @interfaces)){
			@interfaces = grep {!/^<vendor/} @interfaces;
		}
		$type = join(',', @interfaces) if @interfaces;
		# print "type:$type\n";
	}
	return @drivers;
}

sub sys_item {
	my ($path) = @_;
	my ($item);
	$item = main::reader($path,'',0) if -r $path;
	$item = '' if ! defined $item;
	$item = main::trimmer($item) if $item;
	return $item;
}

sub assign_usb_type {
	my ($row) = @_;
	# It's a hub. A device will always be the second or > device on the bus, 
	# although nested hubs of course can be > 1 too. No need to build these if 
	# none of lines are showing.
	if (($row->[4] && $row->[4] eq '09') || 
	($row->[14] && lc($row->[14]) eq 'hub') || $row->[1] <= 1 ||
	(!$show{'audio'} && !$show{'bluetooth'} && !$show{'disk'} && 
	!$show{'graphic'} && !$show{'network'})){
		return;
	}
	$row->[13] = '' if !defined $row->[13]; # product
	$row->[14] = '' if !defined $row->[14]; # type
	$row->[15] = '' if !defined $row->[15]; # driver
	set_asound_ids() if $show{'audio'} && !$b_asound;
	set_network_regex() if $show{'network'} && !$network_regex;
	# NOTE: a device, like camera, can be audio+graphic
	# NOTE: 13, 14 can be upper/lower case, so use i.
	if ($show{'audio'} && (
	(@asound_ids && $row->[7] && (grep {$row->[7] eq $_} @asound_ids)) ||
	($row->[14] && $row->[14] =~ /audio/i) || 
	($row->[15] && $row->[15] =~ /audio/) ||
	($row->[13] && lc($row->[13]) =~ /(audio|\bdac[0-9]*\b|headphone|\bmic(rophone)?\b)/i)
	)){
		push(@{$usb{'audio'}},$row);
	}
	if ($show{'graphic'} && (
	($row->[14] && $row->[14] =~ /video/i) ||
	($row->[15] && $row->[15] =~ /video/) || 
	($row->[13] && lc($row->[13]) =~ /(camera|\bdvb-t|\b(pc)?tv\b|video|webcam)/i)
	)){
		push(@{$usb{'graphics'}},$row);
	}
	# we want to catch bluetooth devices, which otherwise can trip network regex
	elsif (($show{'bluetooth'} || $show{'network'}) && (
	($row->[14] && $row->[14] =~ /bluetooth/i) || 
	($row->[15] && $row->[15] =~ /\b(btusb|ubt)\b/) ||
	($row->[13] && $row->[13] =~ /bluetooth/i)
	)){
		push(@{$usb{'bluetooth'}},$row);
	}
	elsif ($show{'disk'} && (
	($row->[14] && $row->[14] =~ /mass storage/i) || 
	($row->[15] && $row->[15] =~ /storage/)
	)){
		push(@{$usb{'disk'}},$row);
	}
	elsif ($show{'network'} && (
	($row->[14] && $row->[14] =~ /(ethernet|network|wifi)/i) ||
	($row->[15] && $row->[15] =~ /(^ipw|^iwl|wifi)/) || 
	($row->[13] && $row->[13] =~ /($network_regex)/i)
	)){
		push(@{$usb{'network'}},$row);
	}
}

sub device_type {
	my ($data) = @_;
	my ($type);
	# note: the 3/0/0 value passed will be decimal, not hex
	my @types = split('/', $data) if $data;
	# print @types,"\n";
	if (!@types || $types[0] eq '0' || scalar @types != 3){return '';}
	elsif ($types[0] eq '255'){ return '<vendor specific>';}
	if (scalar @types == 3){
		$class_id = $types[0];
		$subclass_id = $types[1];
		$protocol_id = $types[2];
	}
	if ($types[0] eq '1'){
		$type = 'audio';}
	elsif ($types[0] eq '2'){
		if ($types[1] eq '2'){
			$type = 'abstract (modem)';}
		elsif ($types[1] eq '6'){
			$type = 'ethernet network';}
		elsif ($types[1] eq '10'){
			$type = 'mobile direct line';}
		elsif ($types[1] eq '12'){
			$type = 'ethernet emulation';}
		else {
			$type = 'communication';}
	}
	elsif ($types[0] eq '3'){
		if ($types[2] eq '0'){
			$type = 'HID';} # actual value: None
		elsif ($types[2] eq '1'){
			$type = 'keyboard';}
		elsif ($types[2] eq '2'){
			$type = 'mouse';}
	}
	elsif ($types[0] eq '6'){
		$type = 'still imaging';}
	elsif ($types[0] eq '7'){
		$type = 'printer';}
	elsif ($types[0] eq '8'){
		$type = 'mass storage';}
	# note: there is a bug in linux kernel that always makes hubs 9/0/0
	elsif ($types[0] eq '9'){
		if ($types[2] eq '0'){
			$type = 'full speed or root hub';}
		elsif ($types[2] eq '1'){
			$type = 'hi-speed hub with single TT';}
		elsif ($types[2] eq '2'){
			$type = 'hi-speed hub with multiple TTs';}
		# seen protocol 3, usb3 type hub, but not documented on usb.org
		elsif ($types[2] eq '3'){
			$type = 'super-speed hub';}
		# this is a guess, never seen it
		elsif ($types[2] eq '4'){
			$type = 'super-speed+ hub';}
	}
	elsif ($types[0] eq '10'){
		$type = 'CDC-data';}
	elsif ($types[0] eq '11'){
		$type = 'smart card';}
	elsif ($types[0] eq '13'){
		$type = 'content security';}
	elsif ($types[0] eq '14'){
		$type = 'video';}
	elsif ($types[0] eq '15'){
		$type = 'personal healthcare';}
	elsif ($types[0] eq '16'){
		$type = 'audio-video';}
	elsif ($types[0] eq '17'){
		$type = 'billboard';}
	elsif ($types[0] eq '18'){
		$type = 'type-C bridge';}
	elsif ($types[0] eq '88'){
		$type = 'Xbox';}
	elsif ($types[0] eq '220'){
		$type = 'diagnostic';}
	elsif ($types[0] eq '224'){
		if ($types[1] eq '1'){
			$type = 'bluetooth';}
		elsif ($types[1] eq '2'){
			if ($types[2] eq '1'){
				$type = 'host wire adapter';}
			elsif ($types[2] eq '2'){
				$type = 'device wire adapter';}
			elsif ($types[2] eq '3'){
				$type = 'device wire adapter';}
		}
	}
	# print "$data: $type\n";
	return $type;
}

# Device name/driver string based test, return <vendor specific> if not detected
# for linux based tests, and empty for bsd tests
sub check_type {
	my ($name,$driver,$type) = @_;
	$name = lc($name);
	if (($driver && $driver =~ /hub/) || $name =~ /\b(hub)/i){
		$type = 'Hub';
	}
	elsif ($name =~ /(audio|\bdac[0-9]*\b|(head|micro|tele)phone|hifi|\bmidi\b|\bmic\b|sound)/){
		$type = 'Audio';
	}
	# Broadcom HP Portable SoftSailing
	elsif (($driver && $driver =~ /\b(btusb|ubt)\b/) || $name =~ /(bluetooth)/){
		$type = 'Bluetooth'
	}
	elsif (($driver && $driver =~ /video/) || 
	$name =~ /(camera|display|\bdvb-t|\b(pc)?tv\bvideo|webcam)/){
		$type = 'Video';
	}
	elsif ($name =~ /(wlan|wi-?fi|802\.1[15]|(11|54|108|240|300|433|450|900|1300)\s?mbps|(11|54|108|240)g\b|wireless[\s-][bgn]\b|wireless.*adapter)/){
		$type = 'WiFi';
	}
	# note, until freebsd match to actual drivers, these top level driver matches aren't interesting
	elsif (($driver && $bsd_type && $driver =~ /\b(muge)\b/) || 
	 $name =~ /(ethernet|\blan|802\.3|100?\/1000?|gigabit|10\s?G(b|ig)?E)/){
		$type = 'Ethernet';
	}
	# note: audio devices show HID sometimes, not sure why
	elsif ($name =~ /(joystick|keyboard|mouse|trackball)/){
		$type = 'HID';
	}
	elsif (($driver && $driver =~ /^(umass)$/) || 
	$name =~ /\b(disk|drive|flash)\b/){
		$type = 'Mass Storage';
	}
	return $type;
}

# linux only, will create a positive match to sound devices
sub set_asound_ids {
	$b_asound = 1;
	if (-d '/proc/asound'){
		# note: this will double the data, but it's easier this way.
		# binxi tested for -L in the /proc/asound files, and used only those.
		my @files = main::globber('/proc/asound/*/usbid');
		foreach (@files){
			my $id = main::reader($_,'',0);
			push(@asound_ids, $id) if ($id && !(grep {/$id/} @asound_ids));
		}
	}
	main::log_data('dump','@asound_ids',\@asound_ids) if $b_log;
}

# USB networking search string data, because some brands can have other products 
# than wifi/nic cards, they need further identifiers, with wildcards. Putting 
# the most common and likely first, then the less common, then some specifics
sub set_network_regex {
	# belkin=050d; d-link=07d1; netgear=0846; ralink=148f; realtek=0bda; 
	# Atmel, Atheros make other stuff. NOTE: exclude 'networks': IMC Networks
	# intel, ralink bluetooth as well as networking; (WG|WND?A)[0-9][0-9][0-9] netgear IDs
	$network_regex = 'Ethernet|gigabit|\bISDN|\bLAN\b|Mobile\s?Broadband|';
	$network_regex .= '\bNIC\b|wi-?fi|Wireless[\s-][GN]\b|WLAN|';
	$network_regex .= '802\.(1[15]|3)|(10|11|54|108|240|300|450|1300)\s?Mbps|(11|54|108|240)g\b|100?\/1000?|';
	$network_regex .= '(100?|N)Base-?T\b|';
	$network_regex .= '(Actiontec|AirLink|Asus|Belkin|Buffalo|Dell|D-Link|DWA-|ENUWI-|';
	$network_regex .= 'Ralink|Realtek|Rosewill|RNX-|Samsung|Sony|TEW-|TP-Link|';
	$network_regex .= 'Zonet.*ZEW.*).*Wireless|';
	# Note: Intel Bluetooth wireless interface < should be caught by bluetooth tests
	$network_regex .= '(\bD-Link|Network(ing)?|Wireless).*(Adapter|Interface)|';
	$network_regex .= '(Linksys|Netgear|Davicom)|';
	$network_regex .= 'Range(Booster|Max)|Samsung.*LinkStick|\b(WG|WND?A)[0-9][0-9][0-9]|';
	$network_regex .= '\b(050d:935b|0bda:8189|0bda:8197)\b';
}

# For linux, process rev, get mode. For bsds, get rev, speed.
# args: 0: sys/bsd; 1: speed_si; 2: speed_iec; 3: rev; 4: rev_info; 5: rx lanes; 
# 6: tx lanes 
# 1,2,3,4 passed by reference.
sub version_data {
	return if !${$_[1]};
	if ($_[0] eq 'sys'){
		if (${$_[3]} && main::is_numeric(${$_[3]})){
			# as far as we know, 4 will not have subversions, but this may change,
			# check how /sys reports this in coming year(s)
			if (${$_[3]} =~ /^4/){
				${$_[3]} = ${$_[3]} + 0;
			}
			else {
				${$_[3]} = sprintf('%.1f',${$_[3]});
			}
		}
		# BSD rev is synthetic, it's a hack. And no lane data, so not trying.
		if ($b_admin && ${$_[1]} && ${$_[3]} && $_[5] && $_[6] && 
		${$_[3]} =~ /^[1234]/){
			if (${$_[3]} =~ /^[12]/){
				if (${$_[1]} == 1.5){
					${$_[4]} = '1.0';}
				elsif (${$_[1]} == 12){
					${$_[4]} = '1.1';}
				elsif (${$_[1]} == 480){
					${$_[4]} = '2.0';}
			}
			# Note: unless otherwise indicated, 1 lane is 1rx+1tx.
			elsif (${$_[3]} =~ /^3/){
				if (${$_[1]} == 5000){
					${$_[4]} = '3.2 gen-1x1';} # 1 lane
				elsif (${$_[1]} == 10000){
					if ($_[6] == 1){
						${$_[4]} = '3.2 gen-2x1';} # 1 lane
					elsif ($_[6] == 2){
						${$_[4]} = '3.2 gen-1x2';} # 2 lane
				}
				elsif (${$_[1]} == 20000){
					if ($_[6] == 1){
						${$_[4]} = '3.2 gen-3x1';} # 1 lane
					elsif ($_[6] == 2){
						${$_[4]} = '3.2 gen-2x2';} # 2 lane
				}
				# just in case rev: 3.x shows these speeds
				elsif (${$_[1]} == 40000){
					if ($_[6] == 1){
						${$_[4]} = '4-v1 gen-4x1';} # 1 lane
					elsif ($_[6] == 2){
						${$_[4]} = '4-v1 gen-3x2';} # 2 lane
				}
				elsif (${$_[1]} == 80000){
					${$_[4]} = '4-v2 gen-4x2'; # 2 lanes
				}
				${$_[4]} = main::message('usb-mode-mismatch') if !${$_[4]};
			}
			# NOTE: no realworld usb4 data, unclear if these gen are reliable.
			# possible /sys will expose v1/v2/v3. Check future data.
			elsif (${$_[3]} =~ /^4/){
				# gen 2: 10gb x 1 ln
				if (${$_[1]} < 10001){
					${$_[4]} = '4-v1 gen-2x1';} # 1 lane
				# gen2: 10gb x 2 ln; gen3: 20gb x 1 ln. Confirm
				elsif (${$_[1]} < 20001){
					if ($_[6] == 2){
						${$_[4]} = '4-v1 gen-2x2';} # 2 lanes
					elsif ($_[6] == 1){
						${$_[4]} = '4-v1 gen-3x1';} # 1 lane
				}
				# gen3: 20gb x 2 ln; gen4 40gb x 1 ln. Confirm
				elsif (${$_[1]} < 40001){
					if ($_[6] == 2){
						${$_[4]} = '4-v1 gen-3x2';} # 2 lanes
					elsif ($_[6] == 1){
						${$_[4]} = '4-v2 gen-4x1';} # 1 lane
				}
				# 40gb x 2 ln
				elsif (${$_[1]} < 80001){
					${$_[4]} = '4-v2 gen-4x2';} # 2 lanes
				# 3 lanes: 2 tx+tx @ 60gb, 1 rx+rx @ 40gb, wait for data
				elsif (${$_[1]} < 120001){
					${$_[4]} = '4-v2 gen-4x3-asym'; # 3 lanes, asymmetric
				}
				${$_[4]} = main::message('usb-mode-mismatch') if !${$_[4]};
			}
		}
	}
	else {
		(${$_[1]},${$_[3]}) = prep_speed(${$_[1]});
		# bsd rev hardcoded. We want this set to undef if bad data
		${$_[3]} = usb_rev(${$_[1]}) if !${$_[3]};
	}
	# Add Si/IEC units
	if ($extra > 0 && ${$_[1]}){
		# 1 == 1000000 bits
		my $si = ${$_[1]};
		if (${$_[1]} >= 1000){
			${$_[1]} = (${$_[1]}/1000) . ' Gb/s';
		}
		else {
			${$_[1]} = ${$_[1]} . ' Mb/s';
		}
		if ($b_admin){
			$si = (($si*1000**2)/8);
			if ($si < 1000000){
				${$_[2]} = sprintf('%0.0f KiB/s',($si/1024));
			}
			elsif ($si < 1000000000){
				${$_[2]} = sprintf('%0.1f MiB/s',$si/1024**2);
			}
			else {
				${$_[2]} = sprintf('%0.2f GiB/s',($si/1024**3));
			}
		}
	}
	# print Data::Dumper::Dumper \@_;
}

## BSD SPEED/REV ##
# Mapping of speed string to known speeds. Unreliable, very inaccurate, and some
# unconfirmed. Without real data source can never be better than a decent guess.
# args: 0: speed string
sub prep_speed {
	return if !$_[0];
	my $speed_si = $_[0];
	my $rev;
	if ($_[0] =~ /^([0-9\.]+)\s*Mb/){
		$speed_si = $1;
	}
	elsif ($_[0] =~ /^([0-9\.]+)+\s*Gb/){
		$speed_si = $1 * 1000;
	}
	elsif ($_[0] =~ /usb4?\s?120/i){
		$speed_si = 120000;# 4 120Gbps
		$rev = '4';
	}
	elsif ($_[0] =~ /usb4?\s?80/i){
		$speed_si = 80000;# 4 80Gbps
		$rev = '4';
	}
	elsif ($_[0] =~ /usb4?\s?40/i){
		$speed_si = 40000;# 4 40Gbps
		$rev = '4';
	}
	elsif ($_[0] =~ /usb4?\s?20/i){
		$speed_si = 20000;# 4 20Gbps
		$rev = '4';
	}
	elsif ($_[0] =~ /usb\s?20|super[\s-]?speed\s?(\+|plus) gen[\s-]?2x2/i){
		$speed_si = 20000;# 3.2 20Gbps
		$rev = '3.2';
	}
	# could be 3.2, 20000 too, also superspeed+
	elsif ($_[0] =~ /super[\s-]?speed\s?(\+|plus)/i){
		$speed_si = 10000;# 3.1; # can't trust bsds to use superspeed+ but we'll hope
		$rev = '3.1';
	}
	elsif ($_[0] =~ /super[\s-]?speed/i){
		$speed_si = 5000;# 3.0; 
		$rev = '3.0';
	}
	elsif ($_[0] =~ /hi(gh)?[\s-]?speed/i){
		$speed_si = 480; # 2.0, 
		$rev = '2.0';
	}
	elsif ($_[0] =~ /full[\s-]?speed/i){
		$speed_si = 12; # 1.1 - could be full speed 1.1/2.0
		$rev = '1.1';
	}
	elsif ($_[0] =~ /low?[\s-]?speed/i){
		$speed_si = 1.5; # 1.5 - could be 1.0, or low speed 1.1/2.0
		$rev = '1.0';
	}
	else {
		undef $speed_si; # we don't know what the syntax was
	}
	return ($speed_si,$rev);
}

# Try to guess at usb rev version from speed. Unreliable, very inaccurate.
# Note: this will probably be so inaccurate with USB 3.2/4 that it might be best
# to remove this feature at some point, unless better data sources found.
# args: 0: speed
sub usb_rev {
	return if !$_[0] || !main::is_numeric($_[0]);
	my $rev;
	if ($_[0] < 2){
		$rev = '1.0';}
	elsif ($_[0] < 13)
		{$rev = '1.1';}
	elsif ($_[0] < 481){
		$rev = '2.0';}
	# 5 Gbps
	elsif ($_[0] < 5001)
		{$rev = '3.0';} 
	# 10 Gbps, this can be 3.1, 3.2 or 4
	elsif ($_[0] < 10001){
		$rev = '3.1';} 
	# SuperSpeed 'USB 20Gbps', this can be 3.2 or 4
	elsif ($_[0] < 20001){
		$rev = '3.2';} 
	# 4 does not use 4.x syntax, and real lanes/rev/speed data source required.
	# 4: 10-120 Gbps. Update once data available for USB 3.2/4 speed strings
	elsif ($_[0] < 120001){
		$rev = '4';}
	return $rev;
}

## UTILITIES ##
# This is used to create an alpha sortable bus id for main $usb[0]
sub bus_id_alpha {
	my ($id) = @_;
	$id =~ s/^([1-9])-/0$1-/;
	$id =~ s/([-\.:])([0-9])\b/${1}0$2/g;
	return $id;
}

sub process_power {
	return if !${$_[0]};
	${$_[0]} =~ s/\s//g;
	# ${$_[0]} = '' if ${$_[0]} eq '0mA'; # better to handle on output
}
}

########################################################################
#### GENERATE OUTPUT
########################################################################

## OutputGenerator
# Also creates Short, Info, and System items
{