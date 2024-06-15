package DeviceData;
my (@bluetooth,@devices,@files,@full_names,@pcis,@temp,@temp2,@temp3,%lspci_n);
my ($b_bt_check,$b_lspci_n);
my ($busid,$busid_nu,$chip_id,$content,$device,$driver,$driver_nu,$file,
$handle,$modules,$port,$rev,$serial,$temp,$type,$type_id,$vendor,$vendor_id);

sub set {
	eval $start if $b_log;
	${$_[0]} = 1; # set check by reference
	if ($use{'pci'}){
		if (!$bsd_type){
			if ($alerts{'lspci'}->{'action'} eq 'use'){
				lspci_data();
			}
			# ! -d '/proc/bus/pci'
			# this is sketchy, a sbc won't have pci, but a non sbc arm may have it, so 
			# build up both and see what happens
			if (%risc){
				soc_data();
			}
		}
		else {
			# if (1 == 1){
			if ($alerts{'pciconf'}->{'action'} eq 'use'){
				pciconf_data();
			}
			elsif ($alerts{'pcidump'}->{'action'} eq 'use'){
				pcidump_data();
			}
			elsif ($alerts{'pcictl'}->{'action'} eq 'use'){
				pcictl_data();
			}
		}
		if ($dbg[9]){
			print Data::Dumper::Dumper $devices{'audio'};
			print Data::Dumper::Dumper $devices{'bluetooth'};
			print Data::Dumper::Dumper $devices{'graphics'};
			print Data::Dumper::Dumper $devices{'network'};
			print Data::Dumper::Dumper $devices{'hwraid'};
			print Data::Dumper::Dumper $devices{'timer'};
			print "vm: $device_vm\n";
		}
		if ($b_log){
			main::log_data('dump','$devices{audio}',$devices{'audio'});
			main::log_data('dump','$devices{bluetooth}',$devices{'bluetooth'});
			main::log_data('dump','$devices{graphics}',$devices{'graphics'});
			main::log_data('dump','$devices{hwraid}',$devices{'hwraid'});
			main::log_data('dump','$devices{network}',$devices{'network'});
			main::log_data('dump','$devices{timer}',$devices{'timer'});
		}
	}
	undef @devices;
	eval $end if $b_log;
}

sub lspci_data {
	eval $start if $b_log;
	my ($busid_full,$subsystem,$subsystem_id);
	my $data = pci_grabber('lspci');
	# print Data::Dumper::Dumper $data;
	foreach (@$data){
		# print "$_\n";
		if ($device){
			if ($_ eq '~'){
				@temp = ($type,$type_id,$busid,$busid_nu,$device,$vendor_id,$chip_id,
				$rev,$port,$driver,$modules,$driver_nu,$subsystem,$subsystem_id);
				assign_data('pci',\@temp);
				$device = '';
				# print "$busid $device_id r:$rev p: $port\n$type\n$device\n";
			}
			elsif ($_ =~ /^Subsystem.*\[([a-f0-9]{4}:[a-f0-9]{4})\]/){
				$subsystem_id = $1;
				$subsystem = (split(/^Subsystem:\s*/, $_))[1];
				$subsystem =~ s/(\s?\[[^\]]+\])+$//g;
				$subsystem = main::clean($subsystem);
				$subsystem = main::clean_pci($subsystem,'pci');
				$subsystem = main::clean_pci_subsystem($subsystem);
				# print "ss:$subsystem\n";
			}
			elsif ($_ =~ /^I\/O\sports/){
				$port = (split(/\s+/, $_))[3];
				# print "p:$port\n";
			}
			elsif ($_ =~ /^Kernel\sdriver\sin\suse/){
				$driver = (split(/:\s*/, $_))[1];
			}
			elsif ($_ =~ /^Kernel\smodules/i){
				$modules = (split(/:\s*/, $_))[1];
			}
		}
		# note: arm servers can have more complicated patterns
		# 0002:01:02.0 Ethernet controller [0200]: Cavium, Inc. THUNDERX Network Interface Controller virtual function [177d:a034] (rev 08)
		# seen cases of lspci trimming too long lines like this:
		# 01:00.0 Display controller [0380]: Advanced Micro Devices, Inc. [AMD/ATI] Topaz XT [Radeon R7 M260/M265 / M340/M360 / M440/M445 / 530/535 / 620/625 Mobile] [10... (rev c3) (prog-if 00 [Normal decode])
		# \s(.*)\s\[([0-9a-f]{4}):([0-9a-f]{4})\](\s\(rev\s([^\)]+)\))?
		elsif ($_ =~ /^((([0-9a-f]{2,4}:)?[0-9a-f]{2}:[0-9a-f]{2})[.:]([0-9a-f]+))\s+/){
			$busid_full = $1;
			$busid = $2;
			$busid_nu = hex($4);
			($chip_id,$rev,$type,$type_id,$vendor_id) = ('','','','','');
			$_ =~ s/^\Q$busid_full\E\s+//;
			# old systems didn't use [...] but type will get caught in lspci_n check
			if ($_ =~ /^(([^\[]+?)\s+\[([a-f0-9]{4})\]:\s+)/){
				$type = $2;
				$type_id = $3;
				$_ =~ s/^\Q$1\E//;
				$type = lc($type);
				$type = main::clean_pci($type,'pci');
				$type =~ s/\s+$//;
			}
			# trim off end prog-if and rev items
			if ($_ =~ /(\s+\(prog[^\)]+\))/){
				$_ =~ s/\Q$1\E//;
			}
			if ($_ =~ /(\s+\(rev\s+[^\)]+\))/){
				$rev = $2;
				$_ =~ s/\Q$1\E//;
			}
			# get rid of anything in parentheses at end in case other variants show 
			# up, which they probably will.
			if ($_ =~ /((\s+\([^\)]+\))+)$/){
				$_ =~ s/\Q$1\E//;
			}
			if ($_ =~ /(\s+\[([0-9a-f]{4}):([0-9a-f]{4})\])$/){
				$vendor_id = $2;
				$chip_id = $3;
				$_ =~ s/\Q$1\E//;
			}
			# lspci -nnv string trunctation bug
			elsif ($_ =~ /(\s+\[[^\]]*\.\.\.)$/){
				$_ =~ s/\Q$1\E//;
			}
			$device = $_;
			# cases of corrupted string set to ''
			$device = main::clean($device);
			# corrupted lspci truncation bug; and ancient lspci, 2.4 kernels
			if (!$vendor_id){
				my $temp = lspci_n_data($busid_full);
				if (@$temp){
					$type_id = $temp->[0] if !$type_id;
					$vendor_id = $temp->[1];
					$chip_id = $temp->[2];
					$rev = $temp->[3] if !$rev && $temp->[3];
				}
			}
			$use{'hardware-raid'} = 1 if $type_id eq '0104';
			($driver,$driver_nu,$modules,$port,$subsystem,$subsystem_id) = ('','','','','','');
		}
	}
	print Data::Dumper::Dumper \@devices if $dbg[4];
	main::log_data('dump','lspci @devices',\@devices) if $b_log;
	eval $end if $b_log;
}

# args: 0: busID
# returns if valid busID: (classID,vendorID,productID,revNu)
# almost never used, only in case of lspci -nnv line truncation bug
sub lspci_n_data {
	eval $start if $b_log;
	my ($bus_id) = @_;
	if (!$b_lspci_n){
		$b_lspci_n = 1;
		my (@data);
		if ($fake{'lspci'}){
			# my $file = "$fake_data_dir/pci/lspci/steve-mint-topaz-lspci-n.txt";
			# my $file = "$fake_data_dir/pci/lspci/ben81-hwraid-lspci-n.txt";
			# @data = main::reader($file,'strip');
		}
		else {
			@data = main::grabber($alerts{'lspci'}->{'path'} . ' -n 2>/dev/null','','strip');
		}
		foreach (@data){
			if (/^([a-f0-9:\.]+)\s+([a-f0-9]{4}):\s+([a-f0-9]{4}):([a-f0-9]{4})(\s+\(rev\s+([0-9a-z\.]+)\))?/){
				my $rev = (defined $6) ? $6 : '';
				$lspci_n{$1} = [$2,$3,$4,$rev];
			}
		}
		print Data::Dumper::Dumper \%lspci_n if $dbg[4];
		main::log_data('dump','%lspci_n',\%lspci_n) if $b_log;
	}
	my $return = ($lspci_n{$bus_id}) ? $lspci_n{$bus_id}: [];
	print Data::Dumper::Dumper $return if $dbg[50];
	main::log_data('dump','@$return') if $b_log;
	eval $end if $b_log;
	return $return;
}

# em0@pci0:6:0:0:	class=0x020000 card=0x10d315d9 chip=0x10d38086 rev=0x00 hdr=0x00
#     vendor     = 'Intel Corporation'
#     device     = 'Intel 82574L Gigabit Ethernet Controller (82574L)'
#     class      = network
#     subclass   = ethernet
sub pciconf_data {
	eval $start if $b_log;
	my $data = pci_grabber('pciconf');
	foreach (@$data){
		if ($driver){
			if ($_ eq '~'){
				$vendor = main::clean($vendor);
				$device = main::clean($device);
				# handle possible regex in device name, like [ConnectX-3] 
				# and which could make matches fail
				my $device_temp = main::clean_regex($device);
				if ($vendor && $device){
					if (main::clean_regex($vendor) !~ /\Q$device_temp\E/i){
						$device = "$vendor $device";
					}
				}
				elsif (!$device){
					$device = $vendor;
				}
				@temp = ($type,$type_id,$busid,$busid_nu,$device,$vendor_id,$chip_id,
				$rev,$port,$driver,$modules,$driver_nu);
				assign_data('pci',\@temp);
				$driver = '';
				# print "$busid $device_id r:$rev p: $port\n$type\n$device\n";
			}
			elsif ($_ =~ /^vendor/){
				$vendor = (split(/\s+=\s+/, $_))[1];
				# print "p:$port\n";
			}
			elsif ($_ =~ /^device/){
				$device = (split(/\s+=\s+/, $_))[1];
			}
			elsif ($_ =~ /^class/i){
				$type = (split(/\s+=\s+/, $_))[1];
			}
		}
		# pre freebsd 13, note chip is product+vendor
		# atapci0@pci0:0:1:1:	class=0x01018a card=0x00000000 chip=0x71118086 rev=0x01 hdr=0x00
		# freebsd 13
		# isab0@pci0:0:1:0:	class=0x060100 rev=0x00 hdr=0x00 vendor=0x8086 device=0x7000 subvendor=0x0000 subdevice=0x0000
		if (/^([^@]+)\@pci([0-9]{1,3}:[0-9]{1,3}:[0-9]{1,3}):([0-9]{1,3}):/){
			$driver = $1;
			$busid = $2;
			$busid_nu = $3;
			$driver = $1;
			$driver =~ s/([0-9]+)$//;
			$driver_nu = $1;
			# we don't use the sub sub class part of the class id, just first 4
			if (/\bclass=0x([\S]{4})\S*\b/){
				$type_id = $1; 
			}
			if (/\brev=0x([\S]+)\b/){
				$rev = $1;
			}
			if (/\bvendor=0x([\S]+)\b/){
				$vendor_id = $1;
			}
			if (/\bdevice=0x([\S]+)\b/){
				$chip_id = $1;
			}
			# yes, they did it backwards, product+vendor id
			if (/\bchip=0x([a-f0-9]{4})([a-f0-9]{4})\b/){
				$chip_id = $1;
				$vendor_id = $2;
			}
			($device,$type,$vendor) = ('','','');
		}
	}
	print Data::Dumper::Dumper \@devices if $dbg[4];
	main::log_data('dump','pciconf @devices',\@devices) if $b_log;
	eval $end if $b_log;
}

sub pcidump_data {
	eval $start if $b_log;
	my $data = pci_grabber('pcidump');
	main::set_dboot_data() if !$loaded{'dboot'};
	foreach (@$data){
		if ($_ eq '~' && $busid && $device){
			@temp = ($type,$type_id,$busid,$busid_nu,$device,$vendor_id,$chip_id,
			$rev,$port,$driver,$modules,$driver_nu,'','','',$serial);
			assign_data('pci',\@temp);
			($type,$type_id,$busid,$busid_nu,$device,$vendor_id,$chip_id,
			$rev,$port,$driver,$modules,$driver_nu,$serial) = ();
			next;
		}
		if ($_ =~ /^([0-9a-f:]+):([0-9]+):\s([^:]+)$/i){
			$busid = $1;
			$busid_nu = $2;
			($driver,$driver_nu) = pcidump_driver("$busid:$busid_nu") if $dboot{'pci'};
			$device = main::clean($3);
		}
		elsif ($_ =~ /^0x[\S]{4}:\s+Vendor ID:\s+([0-9a-f]{4}),?\s+Product ID:\s+([0-9a-f]{4})/){
			$vendor_id = $1;
			$chip_id = $2;
		}
		elsif ($_ =~ /^0x[\S]{4}:\s+Class:\s+([0-9a-f]{2})(\s[^,]+)?,?\s+Subclass:\s+([0-9a-f]{2})(\s+[^,]+)?,?(\s+Interface: ([0-9a-f]+),?\s+Revision: ([0-9a-f]+))?/){
			$type = pci_class($1);
			$type_id = "$1$3";
		}
		elsif (/^Serial Number:\s*(\S+)/){
			$serial = $1;
		}
	}
	print Data::Dumper::Dumper \@devices if $dbg[4];
	main::log_data('dump','pcidump @devices',\@devices) if $b_log;
	eval $end if $b_log;
}

sub pcidump_driver {
	eval $start if $b_log;
	my $bus_id = $_[0];
	my ($driver,$nu);
	for (@{$dboot{'pci'}}){
		if (/^$bus_id:([^0-9]+)([0-9]+):/){
			$driver = $1;
			$nu = $2;
			last;
		}
	}
	eval $end if $b_log;
	return ($driver,$nu);
}

sub pcictl_data {
	eval $start if $b_log;
	my $data = pci_grabber('pcictl');
	my $data2 = pci_grabber('pcictl-n');
	foreach (@$data){
		if ($_ eq '~' && $busid && $device){
			@temp = ($type,$type_id,$busid,$busid_nu,$device,$vendor_id,$chip_id,
			$rev,$port,$driver,$modules,$driver_nu);
			assign_data('pci',\@temp);
			($type,$type_id,$busid,$busid_nu,$device,$vendor_id,$chip_id,
			$rev,$port,$driver,$modules,$driver_nu) = ();
			next;
		}
		# it's too fragile to get these in one matching so match, trim, next match
		if (/\s+\[([^\]0-9]+)([0-9]+)\]$/){
			$driver = $1;
			$driver_nu = $2;
			$_ =~ s/\s+\[[^\]]+\]$//;
		}
		if (/\s+\(.*?(revision 0x([^\)]+))?\)/){
			$rev = $2 if $2;
			$_ =~ s/\s+\([^\)]+?\)$//;
		}
		if ($_ =~ /^([0-9a-f:]+):([0-9]+):\s+([^.]+?)$/i){
			$busid = $1;
			$busid_nu = $2;
			$device = main::clean($3);
			my $working = (grep {/^${busid}:${busid_nu}:\s/} @$data2)[0];
			if ($working && 
			 $working =~ /^${busid}:${busid_nu}:\s+0x([0-9a-f]{4})([0-9a-f]{4})\s+\(0x([0-9a-f]{2})([0-9a-f]{2})[0-9a-f]+\)/){
				$vendor_id = $1;
				$chip_id = $2;
				$type = pci_class($3);
				$type_id = "$3$4";
			}
		}
	}
	print Data::Dumper::Dumper \@devices if $dbg[4];
	main::log_data('dump','pcidump @devices',\@devices) if $b_log;
	eval $end if $b_log;
}

sub pci_grabber {
	eval $start if $b_log;
	my ($program) = @_;
	my ($args,$path,$pattern,$data);
	my $working = [];
	if ($program eq 'lspci'){
		# 2.2.8 lspci did not support -k, added in 2.2.9, but -v turned on -k 
		$args = ' -nnv';
		$path = $alerts{'lspci'}->{'path'};
		$pattern = q/^[0-9a-f]+:/; # i only added perl 5.14, don't use qr/
	}
	elsif ($program eq 'pciconf'){
		$args = ' -lv';
		$path = $alerts{'pciconf'}->{'path'};
		$pattern = q/^([^@]+)\@pci/; # i only added perl 5.14, don't use qr/
	}
	elsif ($program eq 'pcidump'){
		$args = ' -v';
		$path = $alerts{'pcidump'}->{'path'};
		$pattern = q/^[0-9a-f]+:/; # i only added perl 5.14, don't use qr/
	}
	elsif ($program eq 'pcictl'){
		$args = ' pci0 list -N';
		$path = $alerts{'pcictl'}->{'path'};
		$pattern = q/^[0-9a-f:]+:/; # i only added perl 5.14, don't use qr/
	}
	elsif ($program eq 'pcictl-n'){
		$args = ' pci0 list -n';
		$path = $alerts{'pcictl'}->{'path'};
		$pattern = q/^[0-9a-f:]+:/; # i only added perl 5.14, don't use
	}
	if ($fake{'lspci'} || $fake{'pciconf'} || $fake{'pcictl'} || $fake{'pcidump'}){
		# my $file = "$fake_data_dir/pci/pciconf/pci-freebsd-8.2-2";
		# my $file = "$fake_data_dir/pci/pcidump/pci-openbsd-6.1-vm.txt";
		# my $file = "$fake_data_dir/pci/pcictl/pci-netbsd-9.1-vm.txt";
		# my $file = "$fake_data_dir/pci/lspci/racermach-1-knnv.txt";
		# my $file = "$fake_data_dir/pci/lspci/rk016013-knnv.txt";
		# my $file = "$fake_data_dir/pci/lspci/kot--book-lspci-nnv.txt";
		# my $file = "$fake_data_dir/pci/lspci/steve-mint-topaz-lspci-nnkv.txt";
		# my $file = "$fake_data_dir/pci/lspci/ben81-hwraid-lspci-nnv.txt";
		# my $file = "$fake_data_dir/pci/lspci/gx78b-lspci-nnv.txt";
		# $data = main::reader($file,'strip','ref');
	}
	else {
		$data = main::grabber("$path $args 2>/dev/null",'','strip','ref');
	}
	if (@$data){
		$use{'pci-tool'} = 1 if scalar @$data > 10;
		foreach (@$data){
			# this is the group separator and assign trigger
			if ($_ =~ /$pattern/i){
				push(@$working, '~');
			}
			push(@$working, $_);
		}
		push(@$working, '~');
	}
	print Data::Dumper::Dumper $working if $dbg[30];
	eval $end if $b_log;
	return $working;
}

sub soc_data {
	eval $start if $b_log;
	soc_devices_files();
	soc_devices();
	soc_devicetree();
	print Data::Dumper::Dumper \@devices if $dbg[4];
	main::log_data('dump','soc @devices',\@devices) if $b_log;
	eval $end if $b_log;
}

# 1: /sys/devices/platform/soc/1c30000.ethernet/uevent:["DRIVER=dwmac-sun8i", "OF_NAME=ethernet", 
# "OF_FULLNAME=/soc/ethernet@1c30000", "OF_COMPATIBLE_0=allwinner,sun8i-h3-emac", 
# "OF_COMPATIBLE_N=1", "OF_ALIAS_0=ethernet0", # "MODALIAS=of:NethernetT<NULL>Callwinner,sun8i-h3-emac"]
# 2: /sys/devices/platform/soc:audio/uevent:["DRIVER=bcm2835_audio", "OF_NAME=audio", "OF_FULLNAME=/soc/audio", 
# "OF_COMPATIBLE_0=brcm,bcm2835-audio", "OF_COMPATIBLE_N=1", "MODALIAS=of:NaudioT<NULL>Cbrcm,bcm2835-audio"]
# 3: /sys/devices/platform/soc:fb/uevent:["DRIVER=bcm2708_fb", "OF_NAME=fb", "OF_FULLNAME=/soc/fb", 
# "OF_COMPATIBLE_0=brcm,bcm2708-fb", "OF_COMPATIBLE_N=1", "MODALIAS=of:NfbT<NULL>Cbrcm,bcm2708-fb"]
# 4: /sys/devices/platform/soc/1c40000.gpu/uevent:["OF_NAME=gpu", "OF_FULLNAME=/soc/gpu@1c40000", 
# "OF_COMPATIBLE_0=allwinner,sun8i-h3-mali", "OF_COMPATIBLE_1=allwinner,sun7i-a20-mali", 
# "OF_COMPATIBLE_2=arm,mali-400", "OF_COMPATIBLE_N=3", 
# "MODALIAS=of:NgpuT<NULL>Callwinner,sun8i-h3-maliCallwinner,sun7i-a20-maliCarm,mali-400"]
# 5: /sys/devices/platform/soc/soc:internal-regs/d0018180.gpio/uevent
# 6: /sys/devices/soc.0/1180000001800.mdio/8001180000001800:05/uevent
#  ["DRIVER=AR8035", "OF_NAME=ethernet-phy"
# 7: /sys/devices/soc.0/1c30000.eth/uevent
# 8: /sys/devices/wlan.26/uevent [from pine64]
# 9: /sys/devices/platform/audio/uevent:["DRIVER=bcm2835_AUD0", "OF_NAME=audio"
# 10: /sys/devices/vio/71000002/uevent:["DRIVER=ibmveth", "OF_NAME=l-lan"
# 11: /sys/devices/platform/soc:/soc:i2c-hdmi:/i2c-2/2-0050/uevent:['OF_NAME=hdmiddc'
# 12: /sys/devices/platform/soc:/soc:i2c-hdmi:/uevent:['DRIVER=i2c-gpio', 'OF_NAME=i2c-hdmi'
# 13: /sys/devices/platform/scb/fd580000.ethernet/uevent
# 14: /sys/devices/platform/soc/fe300000.mmcnr/mmc_host/mmc1/mmc1:0001/mmc1:0001:1/uevent (wifi, pi 3,4)
# 15: Pi BT: /sys/devices/platform/soc/fe201000.serial/uevent
# 16: Pi BT: /sys/devices/platform/soc/fe201000.serial/tty/ttyAMA0/hci0
sub soc_devices_files {
	eval $start if $b_log;
	if (-d '/sys/devices/platform/'){
		@files = main::globber('/sys/devices/platform/soc*/*/uevent');
		@temp2 = main::globber('/sys/devices/platform/soc*/*/*/uevent');
		push(@files,@temp2) if @temp2;
		if (-e '/sys/devices/platform/scb'){
			@temp2 = main::globber('/sys/devices/platform/scb/*/uevent');
			push(@files,@temp2) if @temp2;
			@temp2 = main::globber('/sys/devices/platform/scb/*/*/uevent');
			push(@files,@temp2) if @temp2;
		}
		@temp2 = main::globber('/sys/devices/platform/*/uevent');
		push(@files,@temp2) if @temp2;
	}
	if (main::globber('/sys/devices/soc*')){
		@temp2 = main::globber('/sys/devices/soc*/*/uevent');
		push(@files,@temp2) if @temp2;
		@temp2 = main::globber('/sys/devices/soc*/*/*/uevent');
		push(@files,@temp2) if @temp2;
	}
	@temp2 = main::globber('/sys/devices/*/uevent'); # see case 8
	push(@files,@temp2) if @temp2;
	@temp2 = main::globber('/sys/devices/*/*/uevent'); # see case 10
	push(@files,@temp2) if @temp2;
	undef @temp2;
	# not sure why, but even as root/sudo, /subsystem|driver/uevent are unreadable with -r test true
	@files = grep {!/\/(subsystem|driver)\//} @files if @files;
	main::uniq(\@files);
	eval $end if $b_log;
}

sub soc_devices {
	eval $start if $b_log;
	my (@working);
	set_bluetooth() if !$b_bt_check;
	foreach $file (@files){
		next if -z $file;
		$chip_id = $file;
		# variants: /soc/20100000.ethernet/ /soc/soc:audio/ /soc:/ /soc@0/ /soc:/12cb0000.i2c:/
		# mips: /sys/devices/soc.0/1180000001800.mdio/8001180000001800:07/
		# ppc: /sys/devices/vio/71000002/
		$chip_id =~ /\/sys\/devices\/(platform\/)?(soc[^\/]*\/)?([^\/]+\/)?([^\/]+\/)?([^\/\.:]+)([\.:])?([^\/:]+)?:?\/uevent$/;
		$chip_id = $5;
		$temp = $7;
		@working = main::reader($file, 'strip') if -r $file;
		($device,$driver,$handle,$type,$vendor_id) = ();
		foreach my $data (@working){
			@temp2 = split('=', $data);
			if ($temp2[0] eq 'DRIVER'){
				$driver = $temp2[1];
				$driver =~ s/-/_/g if $driver; # kernel uses _, not - in module names
			}
			elsif ($temp2[0] eq 'OF_NAME'){
				$type = $temp2[1];
			}
			# we'll use these paths to test in device tree pci completer
			elsif ($temp2[0] eq 'OF_FULLNAME' && $temp2[1]){
				# we don't want the short names like /soc, /led and so on
				push(@full_names, $temp2[1]) if (() = $temp2[1] =~ /\//g) > 1;
				$handle = (split('@', $temp2[1]))[-1] if $temp2[1] =~ /@/;
			}
			elsif ($temp2[0] eq 'OF_COMPATIBLE_0'){
				@temp3 = split(',', $temp2[1]);
				$device = $temp3[-1];
				$vendor_id = $temp3[0];
			}
		}
		# it's worthless, we can't use it
		next if ! defined $type;
		$type_id = $type;
		if (@bluetooth && $type eq 'serial'){
			my $file_temp = $file;
			$file_temp =~ s/uevent$//;
			$type = 'bluetooth' if grep {/$file_temp/} @bluetooth;
		}
		$chip_id = '' if ! defined $chip_id;
		$vendor_id = '' if ! defined $vendor_id;
		$driver = '' if ! defined $driver;
		$handle = '' if ! defined $handle;
		$busid = (defined $temp && main::is_int($temp)) ? $temp: 0;
		$type = soc_type($type,$vendor_id,$driver);
		($busid_nu,$modules,$port,$rev) = (0,'','','');
		@temp3 = ($type,$type_id,$busid,$busid_nu,$device,$vendor_id,$chip_id,$rev,
		$port,$driver,$modules,'','','',$handle);
		assign_data('soc',\@temp3);
		main::log_data('dump','soc devices: @devices @temp3',\@temp3) if $b_log;
	}
	eval $end if $b_log;
}

sub soc_devicetree {
	eval $start if $b_log;
	# now we want to fill in stuff that was not in /sys/devices/ 
	if (-d '/sys/firmware/devicetree/base/soc'){
		@files = main::globber('/sys/firmware/devicetree/base/soc/*/compatible');
		my $test = (@full_names) ? join('|', sort @full_names) : 'xxxxxx';
		set_bluetooth() if !$b_bt_check;
		foreach $file (@files){
			if ($file !~ m%$test%){
				($handle,$content,$device,$type,$type_id,$vendor_id) = ('','','','','','');
				$content = main::reader($file, 'strip',0) if -r $file;
				$file =~ m%soc/([^@]+)@([^/]+)/compatible$%;
				$type = $1;
				next if !$type || !$content;
				$handle = $2 if $2;
				$type_id = $type;
				if (@bluetooth && $type eq 'serial'){
					my $file_temp = $file;
					$file_temp =~ s/uevent$//;
					$type = 'bluetooth' if grep {/$file_temp/} @bluetooth;
				}
				if ($content){
					@temp3 = split(',', $content);
					$vendor_id = $temp3[0];
					$device = $temp3[-1];
					# strip off those weird device tree special characters
					$device =~ s/\x01|\x02|\x03|\x00//g;
				}
				$type = soc_type($type,$vendor_id,'');
				@temp3 = ($type,$type_id,0,0,$device,$vendor_id,'soc','','','','','','','',$handle);
				assign_data('soc',\@temp3);
				main::log_data('dump','devicetree: @devices @temp3',\@temp3) if $b_log;
			}
		}
	}
	eval $end if $b_log;
}

sub set_bluetooth {
	# special case of pi bt on ttyAMA0
	$b_bt_check = 1;
	@bluetooth = main::globber('/sys/class/bluetooth/*') if -e '/sys/class/bluetooth';
	@bluetooth = map {$_ = Cwd::abs_path($_);$_} @bluetooth if @bluetooth;
	@bluetooth = grep {!/usb/} @bluetooth if @bluetooth; # we only want non usb bt
	main::log_data('dump','soc bt: @bluetooth', \@bluetooth) if $b_log;
}

sub assign_data {
	my ($tool,$data) = @_;
	if (check_graphics($data->[0],$data->[1])){
		push(@{$devices{'graphics'}},[@$data]);
		$use{'soc-gfx'} = 1 if $tool eq 'soc';
	}
	# for hdmi, we need gfx/audio both
	if (check_audio($data->[0],$data->[1])){
		push(@{$devices{'audio'}},[@$data]);
		$use{'soc-audio'} = 1 if $tool eq 'soc';
	}
	if (check_bluetooth($data->[0],$data->[1])){
		push(@{$devices{'bluetooth'}},[@$data]);
		$use{'soc-bluetooth'} = 1 if $tool eq 'soc';
	}
	elsif (check_hwraid($data->[0],$data->[1])){
		push(@{$devices{'hwraid'}},[@$data]);
		$use{'soc-hwraid'} = 1 if $tool eq 'soc';
	}
	elsif (check_network($data->[0],$data->[1])){
		push(@{$devices{'network'}},[@$data]);
		$use{'soc-network'} = 1 if $tool eq 'soc';
	}
	elsif (check_timer($data->[0],$data->[1])){
		push(@{$devices{'timer'}},[@$data]);
		$use{'soc-timer'} = 1 if $tool eq 'soc';
	}
	# not used at this point, -M comes before ANG
	# $device_vm = check_vm($data[4]) if ((!$risc{'ppc'} && !$risc{'mips'}) && !$device_vm);
	push(@devices,[@$data]);
}

# Note: for SOC these have been converted in soc_type()
sub check_audio {
	if (($_[1] && length($_[1]) == 4 && $_[1] =~ /^04/) ||
	 ($_[0] && $_[0] =~ /^(audio|hdmi|multimedia|sound)$/i)){
		return 1;
	}
	else {return 0}
}

sub check_bluetooth {
	if (($_[1] && length($_[1]) == 4 && $_[1] eq '0d11') ||
	 ($_[0] && $_[0] =~ /^(bluetooth)$/i)){
		return 1;
	}
	else {return 0}
}

sub check_graphics {
	# note: multimedia class 04 is video if 0400. 'tv' is risky I think
	if (($_[1] && length($_[1]) == 4 &&  ($_[1] =~ /^03/ || $_[1] eq '0400' || 
	 $_[1] eq '0d80')) || 
	 ($_[0] && $_[0] =~ /^(vga|display|hdmi|3d|video|tv|television)$/i)){
		return 1;
	}
	else {return 0}
}

sub check_hwraid {
	return 1 if ($_[1] && $_[1] eq '0104');
}

# NOTE: class 06 subclass 80 
# https://www-s.acm.illinois.edu/sigops/2007/roll_your_own/7.c.1.html
# 0d20: 802.11a 0d21: 802.11b 0d80: other wireless
sub check_network {
	if (($_[1] && length($_[1]) == 4 && ($_[1] =~/^02/ || $_[1] =~ /^0d2/ || $_[1] eq '0680')) ||
	 ($_[0] && $_[0] =~  /^(ethernet|network|wifi|wlan)$/i)){
		return 1;
	}
	else {return 0}
}

sub check_timer {
	return 1 if ($_[0] && $_[0] eq 'timer');
}

sub check_vm {
	if ($_[0] && $_[0] =~ /(innotek|vbox|virtualbox|vmware|qemu)/i){
		return $1
	}
	else {return ''}
}

sub soc_type {
	my ($type,$info,$driver) = @_;
	# I2S or i2s. I2C is i2 controller |[iI]2[Ss]. note: odroid hdmi item is sound only
	# snd_soc_dummy. simple-audio-amplifier driver: speaker_amp
	if (($driver && $driver =~ /codec/) || ($info && $info =~ /codec/) ||
	 ($type && $type =~ /codec/)){
		$type = 'codec';
	}
	elsif (($driver && $driver =~ /dummy/i) || ($info && $info =~ /dummy/i)){
		$type = 'dummy';
	}
	# rome_vreg reg_fixed_voltage regulator-fixed wlan_en_vreg
	elsif (($driver && $driver =~ /\bv?reg(ulat|_)|voltage/i) || 
	 ($info && $info =~ /_v?reg|\bv?reg(ulat|_)|voltage/i)){
		$type = 'regulator';
	}
	elsif ($type =~ /^(daudio|.*hifi.*|.*sound[_-]card|.*dac[0-9]?)$/i ||
	 ($info && $info !~ /amp/i && $info =~ /(sound|audio)/i) || 
	 ($driver && $driver =~ /(audio|snd|sound)/i)){
		$type = 'audio';
	}
	# no need for bluetooth since that's only found in pi, handled above
	elsif ($type =~ /^((meson-?)?fb|disp|display(-[^\s]+)?|gpu|.*mali|vpu)$/i){
		$type = 'display';
	}
	# includes ethernet-phy, meson-eth
	elsif ($type =~ /^(([^\s]+-)?eth|ethernet(-[^\s]+)?|lan|l-lan)$/i){
		$type = 'ethernet';
	}
	elsif ($type =~ /^(.*wlan.*|.*wifi.*|.*mmcnr.*)$/i){
		$type = 'wifi';
	}
	# needs to catch variants like hdmi-tx but not hdmi-connector
	elsif ($type =~ /^(.*hdmi(-?tx)?)$/i){
		$type = 'hdmi';
	}
	elsif ($type =~ /^timer$/i){
		$type = 'timer';
	}
	return $type;
}

sub pci_class {
	eval $start if $b_log;
	my ($id) = @_;
	$id = lc($id);
	my %classes = (
	'00' => 'unclassified',
	'01' => 'mass-storage',
	'02' => 'network',
	'03' => 'display',
	'04' => 'audio',
	'05' => 'memory',
	'06' => 'bridge',
	'07' => 'communication',
	'08' => 'peripheral',
	'09' => 'input',
	'0a' => 'docking',
	'0b' => 'processor',
	'0c' => 'serialbus',
	'0d' => 'wireless',
	'0e' => 'intelligent',
	'0f' => 'satellite',
	'10' => 'encryption',
	'11' => 'signal-processing',
	'12' => 'processing-accelerators',
	'13' => 'non-essential-instrumentation',
	# 14 - fe reserved
	'40' => 'coprocessor',
	'ff' => 'unassigned',
	);
	my $type = (defined $classes{$id}) ? $classes{$id}: 'unhandled';
	eval $end if $b_log;
	return $type;
}
}

# if > 1, returns first found, not going to be too granular with this yet.
sub get_device_temp {
	eval $start if $b_log;
	my $bus_id = $_[0];
	my $glob = "/sys/devices/pci*/*/*:$bus_id/hwmon/hwmon*/temp*_input";
	my @files = main::globber($glob);
	my $temp;
	foreach my $file (@files){
		$temp = main::reader($file,'strip',0);
		if ($temp){
			$temp = sprintf('%0.1f',$temp/1000);
			last;
		}
	}
	eval $end if $b_log;
	return $temp;
}

## DiskDataBSD
# handles disks and partition extra data for disks bsd, raid-zfs, 
# partitions, swap, unmounted
# glabel: partID, logical/physical-block-size, uuid, label, size
# disklabel: partID, block-size, fs, size
{