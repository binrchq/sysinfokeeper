package UsbItem;

sub get {
	eval $start if $b_log;
	my ($key1,$val1);
	my $rows = [];
	my $num = 0;
	if (!$usb{'main'} && $alerts{'lsusb'}->{'action'} ne 'use' && 
	 $alerts{'usbdevs'}->{'action'} ne 'use' &&
	 $alerts{'usbconfig'}->{'action'} ne 'use'){
		if ($os eq 'linux'){
			$key1 = $alerts{'lsusb'}->{'action'};
			$val1 = $alerts{'lsusb'}->{'message'};
		}
		else {
			# note: usbdevs only has 'missing', usbconfig has missing/permissions
			# both have platform, but irrelevant since testing for linux here
			if ($alerts{'usbdevs'}->{'action'} eq 'missing' && 
			 $alerts{'usbconfig'}->{'action'} eq 'missing'){
				$key1 = $alerts{'usbdevs'}->{'action'};
				$val1 = main::message('tools-missing-bsd','usbdevs/usbconfig');
			}
			elsif ($alerts{'usbconfig'}->{'action'} eq 'permissions'){
				$key1 = $alerts{'usbconfig'}->{'action'};
				$val1 = $alerts{'usbconfig'}->{'message'};
			}
			#	elsif ($alerts{'lsusb'}->{'action'} eq 'missing'){
			#		$key1 = $alerts{'lsusb'}->{'action'};
			#		$val1 = $alerts{'lsusb'}->{'message'};
			#	}
		}
		$key1 = ucfirst($key1);
		@$rows = ({main::key($num++,0,1,$key1) => $val1});
	}
	else {
		usb_output($rows);
		if (!@$rows){
			my $key = 'Message';
			@$rows = ({
			main::key($num++,0,1,$key) => main::message('usb-data','')
			});
		}
	}
	eval $end if $b_log;
	return $rows;
}

sub usb_output {
	eval $start if $b_log;
	return if !$usb{'main'};
	my $rows = $_[0];
	my ($b_hub,$bus_id,$chip_id,$driver,$ind_rc,$ind_sc,$path_id,$ports,$product,
	$rev,$serial,$speed_si,$type);
	my $num = 0;
	my $j = 0;
	# note: the data has been presorted in UsbData:
	# bus alpah id, so we don't need to worry about the order
	foreach my $id (@{$usb{'main'}}){
		$j = scalar @$rows;
		($b_hub,$ind_rc,$ind_sc,$num) = (0,4,3,1);
		($driver,$path_id,$ports,$product,$rev,$serial,$speed_si,
		$type) = ('','','','','','','','','');
		$rev = $id->[8] if $id->[8];
		$product = main::clean($id->[13]) if $id->[13];
		$serial = main::filter($id->[16]) if $id->[16];
		$product ||= 'N/A';
		$rev ||= 'N/A';
		$path_id = $id->[2] if $id->[2];
		$bus_id = "$path_id:$id->[1]";
		# it's a hub
		if ($id->[4] eq '09'){
			$ports = $id->[10] if $id->[10];
			$ports ||= 'N/A';
			# print "pt0:$protocol\n";
			push(@$rows, {
			main::key($num++,1,1,'Hub') => $bus_id,
			main::key($num++,0,2,'info') => $product,
			main::key($num++,0,2,'ports') => $ports,
			},);
			$b_hub = 1;
			$ind_rc =3;
			$ind_sc =2;
		}
		# it's a device
		else {
			$type = $id->[14] if $id->[14];
			$driver = $id->[15] if $id->[15];
			$type ||= 'N/A';
			$driver ||= 'N/A';
			# print "pt3:$class:$product\n";
			$rows->[$j]{main::key($num++,1,2,'Device')} = $bus_id;
			$rows->[$j]{main::key($num++,0,3,'info')} = $product;
			$rows->[$j]{main::key($num++,0,3,'type')} = $type;
			if ($extra > 0){
				$rows->[$j]{main::key($num++,0,3,'driver')} = $driver;
			}
			if ($extra > 2 && $id->[9]){
				$rows->[$j]{main::key($num++,0,3,'interfaces')} = $id->[9];
			}
		}
		# for either hub or device
		$rows->[$j]{main::key($num++,1,$ind_sc,'rev')} = $rev;
		if ($extra > 0){
			$speed_si = ($id->[17]) ? $id->[17] : 'N/A';
			$speed_si .= " ($id->[25])" if ($b_admin && $id->[25]);
			$rows->[$j]{main::key($num++,0,$ind_rc,'speed')} = $speed_si;
			if ($extra > 1){
				if ($id->[24]){
					if ($id->[23] == $id->[24]){
						$rows->[$j]{main::key($num++,0,$ind_rc,'lanes')} = $id->[24];
					}
					else {
						$rows->[$j]{main::key($num++,1,$ind_rc,'lanes')} = '';
						$rows->[$j]{main::key($num++,0,($ind_rc+1),'rx')} = $id->[23];
						$rows->[$j]{main::key($num++,0,($ind_rc+1),'tx')} = $id->[24];
					}
				}
			}
			# 22 is only available if 23 and 24 are present as well
			if ($b_admin && $id->[22]){
				$rows->[$j]{main::key($num++,0,$ind_rc,'mode')} = $id->[22];
			}
			if ($extra > 2 && $id->[19] && $id->[19] ne '0mA'){
				$rows->[$j]{main::key($num++,0,$ind_sc,'power')} = $id->[19];
			}
			$chip_id = $id->[7];
			$chip_id ||= 'N/A';
			$rows->[$j]{main::key($num++,0,$ind_sc,'chip-ID')} = $chip_id;
			if ($extra > 2 && defined $id->[5] && $id->[5] ne ''){
				my $id = sprintf("%02s",$id->[4]) . sprintf("%02s", $id->[5]);
				$rows->[$j]{main::key($num++,0,$ind_sc,'class-ID')} = $id;
			}
			if (!$b_hub && $extra > 2){
				if ($serial){
					$rows->[$j]{main::key($num++,0,$ind_sc,'serial')} = main::filter($serial);
				}
			}
		}
	}
	# print Data::Dumper::Dumper \@rows;
	eval $end if $b_log;
}
}

## WeatherItem
# add metric / imperial (us) switch
{