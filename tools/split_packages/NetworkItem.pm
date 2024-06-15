package NetworkItem;
my ($b_ip_run,@ifs_found);

sub get {
	eval $start if $b_log;
	my $rows = [];
	my $num = 0;
	if (%risc && !$use{'soc-network'} && !$use{'pci-tool'}){
		# do nothing, but keep the test conditions to force 
		# the non arm case to always run
	}
	else {
		device_output($rows);
	}
	# note: raspberry pi uses usb networking only 
	if (!@$rows){
		if (%risc){
			my $key = 'Message';
			@$rows = ({
			main::key($num++,0,1,$key) => main::message('risc-pci',$risc{'id'})
			});
		}
		else {
			my $key = 'Message';
			my $message = '';
			my $type = 'pci-card-data';
			# for some reason, this was in device_output too redundantly
			if ($pci_tool && $alerts{$pci_tool}->{'action'} eq 'permissions'){
				$type = 'pci-card-data-root';
			}
			elsif (!$bsd_type && !%risc && !$pci_tool && 
			$alerts{'lspci'}->{'action'} && 
			$alerts{'lspci'}->{'action'} eq 'missing'){
				$message = $alerts{'lspci'}->{'message'};
			}
			$message = main::message($type,'') if !$message;
			@$rows = ({
			main::key($num++,0,1,$key) => $message
			});
		}
	}
	usb_output($rows);
	if ($show{'network-advanced'}){
		# @ifs_found = ();
		# shift @ifs_found;
		# pop @ifs_found;
		if (!$bsd_type){
			advanced_data_sys($rows,'check','',0,'','','');
		}
		else {
			advanced_data_bsd($rows,'check');
		}
		if ($b_admin){
			info_data($rows);
		}
	}
	if ($show{'ip'}){
		wan_ip($rows);
	}
	eval $end if $b_log;
	return $rows;
}

sub device_output {
	eval $start if $b_log;
	return if !$devices{'network'};
	my $rows = $_[0];
	my ($b_wifi,%holder);
	my ($j,$num) = (0,1);
	foreach my $row (@{$devices{'network'}}){
		$num = 1;
		# print "$row->[0] $row->[3]\n"; 
		# print "$row->[0] $row->[3]\n";
		$j = scalar @$rows;
		my $driver = $row->[9];
		my $chip_id = main::get_chip_id($row->[5],$row->[6]);
		# working around a virtuo bug same chip id is used on two nics
		if (!defined $holder{$chip_id}){
			$holder{$chip_id} = 0;
		}
		else {
			$holder{$chip_id}++; 
		}
		# first check if it's a known wifi id'ed card, if so, no print of duplex/speed
		$b_wifi = check_wifi($row->[4]);
		my $device = $row->[4];
		$device = ($device) ? main::clean_pci($device,'output') : 'N/A';
		#$device ||= 'N/A';
		$driver ||= 'N/A';
		push(@$rows, {
		main::key($num++,1,1,'Device') => $device,
		},);
		if ($extra > 0 && $use{'pci-tool'} && $row->[12]){
			my $item = main::get_pci_vendor($row->[4],$row->[12]);
			$rows->[$j]{main::key($num++,0,2,'vendor')} = $item if $item;
		}
		if ($row->[1] eq '0680'){
			$rows->[$j]{main::key($num++,0,2,'type')} = 'network bridge';
		}
		$rows->[$j]{main::key($num++,1,2,'driver')} = $driver;
		my $bus_id = 'N/A';
		# note: for arm/mips we want to see the single item bus id, why not?
		# note: we can have bus id: 0002 / 0 which is valid, but 0 / 0 is invalid
		if (defined $row->[2] && $row->[2] ne '0' && defined $row->[3]){
			$bus_id = "$row->[2].$row->[3]"}
		elsif (defined $row->[2] && $row->[2] ne '0'){
			$bus_id = $row->[2]}
		elsif (defined $row->[3] && $row->[3] ne '0'){
			$bus_id = $row->[3]}
		if ($extra > 0){
			if ($row->[9] && !$bsd_type){
				my $version = main::get_module_version($row->[9]);
				$version ||= 'N/A';
				$rows->[$j]{main::key($num++,0,3,'v')} = $version;
			}
			if ($b_admin && $row->[10]){
				$row->[10] = main::get_driver_modules($row->[9],$row->[10]);
				$rows->[$j]{main::key($num++,0,3,'modules')} = $row->[10] if $row->[10];
			}
			$row->[8] ||= 'N/A';
			if ($extra > 1 && $bus_id ne 'N/A'){
				main::get_pcie_data($bus_id,$j,$rows,\$num);
			}
			# as far as I know, wifi has no port, but in case it does in future, use it
			if (!$b_wifi || ($b_wifi && $row->[8] ne 'N/A')){
				$rows->[$j]{main::key($num++,0,2,'port')} = $row->[8];
			}
			$rows->[$j]{main::key($num++,0,2,'bus-ID')} = $bus_id;
		}
		if ($extra > 1){
			$rows->[$j]{main::key($num++,0,2,'chip-ID')} = $chip_id;
		}
		if ($extra > 2 && $row->[1]){
			$rows->[$j]{main::key($num++,0,2,'class-ID')} = $row->[1];
		}
		if (!$bsd_type && $extra > 0 && $bus_id ne 'N/A' && $bus_id =~ /\.0$/){
			my $temp = main::get_device_temp($bus_id);
			if ($temp){
				$rows->[$j]{main::key($num++,0,2,'temp')} = $temp . ' C';
			}
		}
		if ($show{'network-advanced'}){
			my @data;
			if (!$bsd_type){
				advanced_data_sys($rows,$row->[5],$row->[6],$holder{$chip_id},$b_wifi,'',$bus_id);
			}
			else {
				if (defined $row->[9] && defined $row->[11]){
					advanced_data_bsd($rows,"$row->[9]$row->[11]",$b_wifi);
				}
			}
		}
		# print "$row->[0]\n";
	}
	# @rows = ();
	eval $end if $b_log;
}

sub usb_output {
	eval $start if $b_log;
	return if !$usb{'network'};
	my $rows = $_[0];
	my (@temp2,$b_wifi,$driver,$path,$path_id,$product,$type);
	my ($j,$num) = (0,1);
	foreach my $row (@{$usb{'network'}}){
		$num = 1;
		($driver,$path,$path_id,$product,$type) = ('','','','','');
		$product = main::clean($row->[13]) if $row->[13];
		$driver = $row->[15] if $row->[15];
		$path = $row->[3] if $row->[3];
		$path_id = $row->[2] if $row->[2];
		$type = $row->[14] if $row->[14];
		$driver ||= 'N/A';
		$j = scalar @$rows;
		push(@$rows, {
		main::key($num++,1,1,'Device') => $product,
		main::key($num++,0,2,'driver') => $driver,
		main::key($num++,1,2,'type') => 'USB',
		},);
		$b_wifi = check_wifi($product);
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
		if ($show{'network-advanced'}){
			if (!$bsd_type){
				my (@temp,$vendor,$chip);
				@temp = split(':', $row->[7]) if $row->[7];
				($vendor,$chip) = ($temp[0],$temp[1]) if @temp;
				advanced_data_sys($rows,$vendor,$chip,0,$b_wifi,$path,'');
			}
			# NOTE: we need the driver + driver nu, like wlp0 to get a match,
			else {
				$driver .= $row->[21] if defined $row->[21];
				advanced_data_bsd($rows,$driver,$b_wifi);
			}
		}
	}
	eval $end if $b_log;
}

sub advanced_data_sys {
	eval $start if $b_log;
	return if ! -d '/sys/class/net';
	my ($rows,$vendor,$chip,$count,$b_wifi,$path_usb,$bus_id) = @_;
	my ($cont_if,$ind_if,$j,$num) = (2,3,0,0);
	my $key = 'IF';
	my ($b_check,$b_usb,$if,$path,@paths);
	# ntoe: we've already gotten the base path, now we 
	# we just need to get the IF path, which is one level in:
	# usb1/1-1/1-1:1.0/net/enp0s20f0u1/
	if ($path_usb){
		$b_usb = 1;
		@paths = main::globber("${path_usb}*/net/*");
	}
	else {
		@paths = main::globber('/sys/class/net/*');
	}
	@paths = grep {!/\/lo$/} @paths;
	# push(@paths,'/sys/class/net/ppp0'); # fake IF if needed to match test data
	if ($count > 0 && $count < scalar @paths){
		@paths = splice(@paths, $count, scalar @paths);
	}
	if ($vendor eq 'check'){
		$b_check = 1;
		$key = 'IF-ID';
		($cont_if,$ind_if) = (1,2);
	}
	# print join('; ', @paths),  $count, "\n";
	foreach (@paths){
		my ($data1,$data2,$duplex,$mac,$speed,$state);
		$j = scalar @$rows;
		# for usb, we already know where we are
		if (!$b_usb){
			# pi mmcnr has pcitool and also these vendor/device paths.
			if (!%risc || $use{'pci-tool'}){
				$path = "$_/device/vendor";
				$data1 = main::reader($path,'',0) if -r $path;
				$data1 =~ s/^0x// if $data1;
				$path = "$_/device/device";
				$data2 = main::reader($path,'',0) if -r $path;
				$data2 =~ s/^0x// if $data2;
				# this is a fix for a redhat bug in virtio 
				$data2 = (defined $data2 && $data2 eq '0001' && defined $chip && $chip eq '1000') ? '1000' : $data2;
			}
			# there are cases where arm devices have a small pci bus
			# or, with mmcnr devices, will show device/vendor info in data1/2
			# which won't match with the path IDs
			if (%risc && $chip && Cwd::abs_path($_) =~ /\b$chip\b/){
				$data1 = $vendor;
				$data2 = $chip;
			}
		}
		# print "d1:$data1 v:$vendor d2:$data2 c:$chip bus_id: $bus_id\n";
		# print Cwd::abs_path($_), "\n" if $bus_id;
		if ($b_usb || $b_check || ($data1 && $data2 && $data1 eq $vendor && $data2 eq $chip && 
		 (%risc || check_bus_id($_,$bus_id)))){
			$if = $_;
			$if =~ s/^\/.+\///;
			# print "top: if: $if ifs: @ifs_found\n";
			next if ($b_check && grep {/$if/} @ifs_found);
			$path = "$_/duplex";
			$duplex = main::reader($path,'',0) if -r $path;
			$duplex ||= 'N/A';
			$path = "$_/address";
			$mac = main::reader($path,'',0) if -r $path;
			$mac = main::filter($mac);
			$path = "$_/speed";
			$speed = main::reader($path,'',0) if -r $path;
			$speed ||= 'N/A';
			$path = "$_/operstate";
			$state = main::reader($path,'',0) if -r $path;
			$state ||= 'N/A';
			# print "$speed \n";
			push(@$rows,{
			main::key($num++,1,$cont_if,$key) => $if,
			main::key($num++,0,$ind_if,'state') => $state
			});
			# my $j = scalar @row - 1;
			push(@ifs_found, $if) if (!$b_check && (! grep {/$if/} @ifs_found));
			# print "push: if: $if ifs: @ifs_found\n";
			# no print out for wifi since it doesn't have duplex/speed data available
			# note that some cards show 'unknown' for state, so only testing explicitly
			# for 'down' string in that to skip showing speed/duplex
			# /sys/class/net/$if/wireless : not always there, but worth a try: wlan/wl/ww/wlp
			$b_wifi = 1 if !$b_wifi && (-e "$_$if/wireless" || $if =~ /^(wl|ww)/);
			if (!$b_wifi && $state ne 'down' && $state ne 'no'){
				# make sure the value is strictly numeric before appending Mbps
				$speed = (main::is_int($speed)) ? "$speed Mbps" : $speed;
				$rows->[$j]{main::key($num++,0,$ind_if,'speed')} = $speed;
				$rows->[$j]{main::key($num++,0,$ind_if,'duplex')} = $duplex;
			}
			$rows->[$j]{main::key($num++,0,$ind_if,'mac')} = $mac;
			#	if ($b_check){
			#		push(@rows,@row);
			#	}
			#	else {
			#		@rows = @row;
			#	}
			if ($show{'ip'}){
				if_ip($rows,$key,$if);
			}
			last if !$b_check;
		}
	}
	eval $end if $b_log;
}

sub advanced_data_bsd {
	eval $start if $b_log;
	return if ! @ifs_bsd;
	my ($rows,$if,$b_wifi) = @_;
	my ($data,$working_if);
	my ($b_check,$state,$speed,$duplex,$mac);
	my ($cont_if,$ind_if,$j,$num) = (2,3,0,0);
	my $key = 'IF';
	if ($if eq 'check'){
		$b_check = 1;
		$key = 'IF-ID';
		($cont_if,$ind_if) = (1,2);
	}
	foreach my $item (@ifs_bsd){
		if (ref $item ne 'ARRAY'){
			$working_if = $item;
			# print "$working_if\n";
			next;
		} 
 		else {
			$data = $item;
 		}
		if ($b_check || $working_if eq $if){
			$if = $working_if if $b_check;
			# print "top1: if: $if ifs: wif: $working_if @ifs_found\n";
			next if ($b_check && grep {/$if/} @ifs_found);
			# print "top2: if: $if wif: $working_if ifs: @ifs_found\n";
			# print Data::Dumper::Dumper $data;
			# ($state,$speed,$duplex,$mac)
			$duplex = $data->[2];
			$duplex ||= 'N/A';
			$mac = main::filter($data->[3]);
			$speed = $data->[1];
			$speed ||= 'N/A';
			$state = $data->[0];
			$state ||= 'N/A';
			$j = scalar @$rows;
			# print "$speed \n";
			push(@$rows, {
			main::key($num++,1,$cont_if,$key) => $if,
			main::key($num++,0,$ind_if,'state') => $state,
			});
			push(@ifs_found, $if) if (!$b_check && (!grep {/$if/} @ifs_found));
			# print "push: if: $if ifs: @ifs_found\n";
			# no print out for wifi since it doesn't have duplex/speed data available
			# note that some cards show 'unknown' for state, so only testing explicitly
			# for 'down' string in that to skip showing speed/duplex
			if (!$b_wifi && $state ne 'down' && $state ne 'no network'){
				# make sure the value is strictly numeric before appending Mbps
				$speed = (main::is_int($speed)) ? "$speed Mbps" : $speed;
				$rows->[$j]{main::key($num++,0,$ind_if,'speed')} = $speed;
				$rows->[$j]{main::key($num++,0,$ind_if,'duplex')} = $duplex;
			}
			$rows->[$j]{main::key($num++,0,$ind_if,'mac')} = $mac;
			if ($show{'ip'} && $if){
				if_ip($rows,$key,$if);
			}
		}
	}
	eval $end if $b_log;
}

## Result values:
# 0: ipv 
# 1: ip 
# 2: broadcast, if found 
# 3: scope, if found 
# 4: scope IF, if different from IF
sub if_ip {
	eval $start if $b_log;
	my ($rows,$type,$if) = @_;
	my ($working_if);
	my ($cont_ip,$ind_ip,$if_cnt) = (3,4,0);
	my ($j,$num) = (0,0);
	$b_ip_run = 1;
	if ($type eq 'IF-ID'){
		($cont_ip,$ind_ip) = (2,3);
	}
	OUTER:
	foreach my $item (@ifs){
		if (ref $item ne 'ARRAY'){
			$working_if = $item;
			# print "if:$if wif:$working_if\n";
			next;
		} 
		if ($working_if eq $if){
			$if_cnt = 0;
			# print "if $if item:\n", Data::Dumper::Dumper $item;
			foreach my $data2 (@$item){
				$j = scalar @$rows;
				$num = 1;
				$if_cnt++;
				if ($limit > 0 && $if_cnt > $limit){
					push(@$rows, {
					main::key($num++,0,$cont_ip,'Message') => main::message('output-limit',scalar @$item),
					});
					last OUTER;
				}
				# print "$data2->[0] $data2->[1]\n";
				my ($ipv,$ip,$broadcast,$scope,$scope_id);
				$ipv = ($data2->[0])? $data2->[0]: 'N/A';
				$ip = main::filter($data2->[1]);
				$scope = ($data2->[3])? $data2->[3]: 'N/A';
				# note: where is this ever set to 'all'? Old test condition?
				if ($if ne 'all'){
					if (defined $data2->[4] && $working_if ne $data2->[4]){
						# scope global temporary deprecated dynamic 
						# scope global dynamic 
						# scope global temporary deprecated dynamic 
						# scope site temporary deprecated dynamic 
						# scope global dynamic noprefixroute enx403cfc00ac68
						# scope global eth0
						# scope link
						# scope site dynamic 
						# scope link 
						# trim off if at end of multi word string if found
						$data2->[4] =~ s/\s$if$// if $data2->[4] =~ /[^\s]+\s$if$/;
						my $key = ($data2->[4] =~ /deprecated|dynamic|temporary|noprefixroute/) ? 'type' : 'virtual';
						push(@$rows, {
						main::key($num++,1,$cont_ip,"IP v$ipv") => $ip,
						main::key($num++,0,$ind_ip,$key) => $data2->[4],
						main::key($num++,0,$ind_ip,'scope') => $scope,
						});
					}
					else {
						push(@$rows, {
						main::key($num++,1,$cont_ip,"IP v$ipv") => $ip,
						main::key($num++,0,$ind_ip,'scope') => $scope,
						});
					}
				}
				else {
					push(@$rows, {
					main::key($num++,1,($cont_ip - 1),'IF') => $if,
					main::key($num++,1,$cont_ip,"IP v$ipv") => $ip,
					main::key($num++,0,$ind_ip,'scope') => $scope,
					});
				}
				if ($extra > 1 && $data2->[2]){
					$broadcast = main::filter($data2->[2]);
					$rows->[$j]{main::key($num++,0,$ind_ip,'broadcast')} = $broadcast;
				}
			}
		}
	}
	eval $end if $b_log;
}

sub info_data {
	eval $start if $b_log;
	my ($rows) = @_;
	my $j = scalar @$rows;
	my $num = 0;
	my $services;
	PsData::set_network();
	if (@{$ps_data{'network-services'}}){
		main::make_list_value($ps_data{'network-services'},\$services,',','sort');
	}
	else {
		$services = main::message('network-services');
	}
	push(@$rows,{
	main::key($num++,1,1,'Info') => '',
	main::key($num++,0,2,'services') => $services,
	});
	eval $end if $b_log;
}

# Get ip using downloader to stdout. This is a clean, text only IP output url,
# single line only, ending in the ip address. May have to modify this in the future
# to handle ipv4 and ipv6 addresses but should not be necessary.
# ip=$(echo  2001:0db8:85a3:0000:0000:8a2e:0370:7334 | gawk  --re-interval '
# ip=$(wget -q -O - $WAN_IP_URL | gawk  --re-interval '
# this generates a direct dns based ipv4 ip address, but if opendns.com goes down, 
# the fall backs will still work. 
# note: consistently slower than domain based: 
# dig +short +time=1 +tries=1 myip.opendns.com. A @208.67.222.222
sub wan_ip {
	eval $start if $b_log;
	my $rows = $_[0];
	my ($b_dig,$b_html,$ip,$ua);
	my $num = 0;
	# time: 0.06 - 0.07 seconds
	# Cisco opendns.com may be terminating supporting this one, sometimes works, sometimes not: 
	# use -4/6 to force ipv 4 or 6, but generally we want the 'natural' native ip returned.
	# dig +short +time=1 +tries=1 myip.opendns.com @resolver1.opendns.com :: 0.021s
	# Works but is slow:
	# dig +short @ns1-1.akamaitech.net ANY whoami.akamai.net :: 0.156s
	# This one can take forever, and sometimes requires explicit -4 or -6
	# dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com :: 0.026s; 1.087ss
	if (!$force{'no-dig'} && (my $program = main::check_program('dig'))){
		$ip = (main::grabber("$program +short +time=1 +tries=1 \@ns1-1.akamaitech.net ANY whoami.akamai.net 2>/dev/null"))[0];
		$ip =~ s/"//g if $ip; # some return IP in quotes, when using TXT
		$b_dig = 1;
	}
	if (!$ip && !$force{'no-html-wan'}){
		# if dig failed or is not installed, set downloader data if unset
		if (!defined $dl{'no-ssl'}){
			main::set_downloader();
		}
		# note: tests: akamai: 0.015 - 0.025 icanhazip.com: 0.020 0.030
		# smxi: 0.230, so ~10x slower. Dig is not as fast as you'd expect
		# dig: 0.167s 0.156s
		# leaving smxi as last test because I know it will always be up.
		# --wan-ip-url replaces values with user supplied arg
		# 0.020s: http://whatismyip.akamai.com/
		# 0.136s: https://get.geojs.io/v1/ip
		# 0.024s: http://icanhazip.com/
		# 0.027s: ifconfig.io
		# 0.230s: https://smxi.org/opt/ip.php
		# 0.023s: https://api.ipify.org :: NOTE: hangs, widely variable times, don't use
		my @urls = (!$wan_url) ? qw(http://whatismyip.akamai.com/ 
		http://icanhazip.com/ https://smxi.org/opt/ip.php) : ($wan_url);
		foreach (@urls){
			$ua = 'ip' if $_ =~ /smxi/;
			$ip = main::download_file('stdout',$_,'',$ua);
			if ($ip){
				# print "$_\n";
				chomp($ip);
				$ip = (split(/\s+/, $ip))[-1];
				last;
			}
		}
		$b_html = 1;
	}
	if ($ip && $use{'filter'}){
		$ip = $filter_string;
	}
	if (!$ip){
		# true case trips
		if (!$b_dig){
			$ip = main::message('IP-no-dig', 'WAN IP'); 
		}
		elsif ($b_dig && !$b_html){
			$ip = main::message('IP-dig', 'WAN IP');
		}
		else {
			$ip = main::message('IP', 'WAN IP');
		}
	}
	push(@$rows, {
	main::key($num++,0,1,'WAN IP') => $ip,
	});
	eval $end if $b_log;
}

sub check_bus_id {
	eval $start if $b_log;
	my ($path,$bus_id) = @_;
	my ($b_valid);
	if ($bus_id){
		# legacy, not link, but uevent has path: 
		# PHYSDEVPATH=/devices/pci0000:00/0000:00:0a.1/0000:05:00.0
		if (Cwd::abs_path($path) =~ /$bus_id\// || 
		 (-r "$path/uevent" && -s "$path/uevent" && 
		 (grep {/$bus_id/} main::reader("$path/uevent")))){
			$b_valid = 1;
		}
	}
	eval $end if $b_log;
	return $b_valid;
}

sub check_wifi {
	my ($item) = @_;
	my $b_wifi = ($item =~ /wireless|wi-?fi|wlan|802\.11|centrino/i) ? 1 : 0;
	return $b_wifi;
}
}

## OpticalItem
{