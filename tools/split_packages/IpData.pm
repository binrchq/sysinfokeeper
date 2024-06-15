package IpData;

sub set {
	eval $start if $b_log;
	if ($force{'ip'} || 
	(!$force{'ifconfig'} && $alerts{'ip'}->{'action'} eq 'use')){
		set_ip_addr();
	}
	elsif ($force{'ifconfig'} || $alerts{'ifconfig'}->{'action'} eq 'use'){
		set_ifconfig();
	}
	eval $end if $b_log;
}

sub set_ip_addr {
	eval $start if $b_log;
	my @data = main::grabber($alerts{'ip'}->{'path'} . " addr 2>/dev/null",'\n','strip');
	if ($fake{'ip-if'}){
		# my $file = "$fake_data_dir/if/scope-ipaddr-1.txt";
		# my $file = "$fake_data_dir/network/ip-addr-blue-advance.txt";
		# my $file = "$fake_data_dir/network/ppoe/ppoe-ip-address-1.txt";
		# my $file = "$fake_data_dir/network/ppoe/ppoe-ip-addr-2.txt";
		# my $file = "$fake_data_dir/network/ppoe/ppoe-ip-addr-3.txt";
		# @data = main::reader($file,'strip') or die $!;
	}
	my ($b_skip,$broadcast,$if,$if_id,$ip,@ips,$scope,$type,@temp,@temp2);
	foreach (@data){
		if (/^[0-9]/){
			# print "$_\n";
			if (@ips){
				# print "$if\n";
				push(@ifs,($if,[@ips]));
				@ips = ();
			}
			@temp = split(/:\s+/, $_);
			$if = $temp[1];
			if ($if eq 'lo'){
				$b_skip = 1;
				$if = '';
				next;
			}
			($b_skip,@temp) = ();
		}
		elsif (!$b_skip && /^inet/){
			# print "$_\n";
			($broadcast,$ip,$scope,$if_id,$type) = ();
			@temp = split(/\s+/, $_);
			$ip = $temp[1];
			$type = ($temp[0] eq 'inet') ? 4 : 6 ;
			if ($temp[2] eq 'brd'){
				$broadcast = $temp[3];
			}
			if (/scope\s([^\s]+)(\s(.+))?/){
				$scope = $1;
				$if_id = $3;
			}
			push(@ips,[$type,$ip,$broadcast,$scope,$if_id]);
			# print Data::Dumper::Dumper \@ips;
		}
	}
	if (@ips){
		push(@ifs,($if,[@ips]));
	}
	main::log_data('dump','@ifs',\@ifs) if $b_log;
	print 'ip addr: ', Data::Dumper::Dumper \@ifs if $dbg[3];
	eval $end if $b_log;
}

sub set_ifconfig {
	eval $start if $b_log;
	# whitespace matters!! Don't use strip
	my @data = main::grabber($alerts{'ifconfig'}->{'path'} . " 2>/dev/null",'\n','');
	if ($fake{'ip-if'}){
		#  my $file = "$fake_data_dir/network/ppoe/ppoe-ifconfig-all-1.txt";
		# my $file = "$fake_data_dir/network/vps-ifconfig-1.txt";
		# @data = main::reader($file) or die $!;
	}
	my ($b_skip,$broadcast,$if,@ips_bsd,$ip,@ips,$scope,$if_id,$type,@temp,@temp2);
	my ($state,$speed,$duplex,$mac);
	foreach (@data){
		if (/^[\S]/i){
			# print "$_\n";
			if (@ips){
			# print "here\n";
				push(@ifs,($if,[@ips]));
				@ips = ();
			}
			if ($mac){
				push(@ifs_bsd,($if,[$state,$speed,$duplex,$mac]));
				($state,$speed,$duplex,$mac,$if_id) = ('','','','','');
			}
			$if = (split(/\s+/, $_))[0];
			$if =~ s/:$//; # em0: flags=8843
			$if_id = $if;
			$if = (split(':', $if))[0] if $if;
			if ($if =~ /^lo/){
				$b_skip = 1;
				$if = '';
				$if_id = '';
				next;
			}
			$b_skip = 0;
		}
		elsif (!$b_skip && $bsd_type && /^\s+(address|ether|media|status|lladdr)/){
			$_ =~ s/^\s+//;
			# freebsd 7.3: media: Ethernet 100baseTX <full-duplex>
			# Freebsd 8.2/12.2: media: Ethernet autoselect (1000baseT <full-duplex>) 
			# Netbsd 9.1: media: Ethernet autoselect (1000baseT full-duplex) 
			# openbsd: media: Ethernet autoselect (1000baseT full-duplex)
			if (/^media/){
				if ($_ =~ /[\s\(]([1-9][^\(\s]+)?\s<([^>]+)>/){
					$speed = $1 if $1;
					$duplex = $2;
				}
				if (!$duplex && $_ =~ /\s\(([\S]+)\s([^\s<]+)\)/){
					$speed = $1;
					$duplex = $2;
				}
				if (!$speed && $_ =~ /\s\(([1-9][\S]+)\s/){
					$speed = $1;
				}
			}
			# lladdr openbsd/address netbsd/ether freebsd
			elsif (!$mac && /^(address|ether|lladdr)/){
				$mac = (split(/\s+/, $_))[1];
			}
			elsif (/^status:\s*(.*)/){
				$state = $1;
			}
		}
		elsif (!$b_skip && /^\s+inet/){
			# print "$_\n";
			$_ =~ s/^\s+//;
			$_ =~ s/addr:\s/addr:/;
			@temp = split(/\s+/, $_);
			($broadcast,$ip,$scope,$type) = ('','','','');
			$ip = $temp[1];
			# fe80::225:90ff:fe13:77ce%em0
# 			$ip =~ s/^addr:|%([\S]+)//;
			if ($1 && $1 ne $if_id){
				$if_id = $1;
			}
			$type = ($temp[0] eq 'inet') ? 4 : 6 ;
			if (/(Bcast:|broadcast\s)([\S]+)/){
				$broadcast = $2;
			}
			if (/(scopeid\s[^<]+<|Scope:|scopeid\s)([^>]+)[>]?/){
				$scope = $2;
			}
			$scope = 'link' if $ip =~ /^fe80/;
			push(@ips,[$type,$ip,$broadcast,$scope,$if_id]);
			# print Data::Dumper::Dumper \@ips;
		}
	}
	if (@ips){
		push(@ifs,($if,[@ips]));
	}
	if ($mac){
		push(@ifs_bsd,($if,[$state,$speed,$duplex,$mac]));
		($state,$speed,$duplex,$mac) = ('','','','');
	}
	print 'ifconfig: ', Data::Dumper::Dumper \@ifs if $dbg[3];
	print 'ifconfig bsd: ', Data::Dumper::Dumper \@ifs_bsd if $dbg[3];
	main::log_data('dump','@ifs',\@ifs) if $b_log;
	main::log_data('dump','@ifs_bsd',\@ifs_bsd) if $b_log;
	eval $end if $b_log;
}
}

sub get_kernel_bits {
	eval $start if $b_log;
	my $bits = '';
	if (my $program = check_program('getconf')){
		# what happens with future > 64 bit kernels? we'll see in the future!
		if ($bits = (grabber("$program _POSIX_V6_LP64_OFF64 2>/dev/null"))[0]){
			if ($bits =~ /^(-1|undefined)$/i){
				$bits = 32;
			}
			# no docs for true state, 1 is usually true, but probably can be others
			else {
				$bits = 64;
			}
		}
		# returns long bits if we got nothing on first test
		$bits = (grabber("$program LONG_BIT 2>/dev/null"))[0] if !$bits;
	}
	# fallback test
	if (!$bits && $bits_sys){
		$bits = $bits_sys;
	}
	$bits ||= 'N/A';
	eval $end if $b_log;
	return $bits;
}

# arg: 0: $cs_curr, by ref; 1: $cs_avail, by ref.
sub get_kernel_clocksource {
	eval $start if $b_log;
	if (-r '/sys/devices/system/clocksource/clocksource0/current_clocksource'){
		${$_[0]} = reader('/sys/devices/system/clocksource/clocksource0/current_clocksource','',0);
		if ($b_admin &&
		-r '/sys/devices/system/clocksource/clocksource0/available_clocksource'){
			${$_[1]} = reader('/sys/devices/system/clocksource/clocksource0/available_clocksource','',0);
			if (${$_[0]} && ${$_[1]}){
				my @temp = split(/\s+/,${$_[1]});
				@temp = grep {$_ ne ${$_[0]}} @temp;
				${$_[1]} = join(',', @temp);
			}
		}
	}
	eval $end if $b_log;
}

## KernelCompiler
{