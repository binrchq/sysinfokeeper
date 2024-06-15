package MachineItem;

sub get {
	eval $start if $b_log;
	my (%soc_machine,$data,@rows,$key1,$val1,$which);
	my $rows = [];
	my $num = 0;
	if ($bsd_type && $sysctl{'machine'} && !$force{'dmidecode'}){
		$data = machine_data_sysctl();
		if (%$data){
			machine_output($rows,$data);
		}
		elsif (!$key1){
			$key1 = 'Message';
			$val1 = main::message('machine-data-force-dmidecode','');
		}
	}
	elsif ($bsd_type || $force{'dmidecode'}){
		if (!$fake{'dmidecode'} && $alerts{'dmidecode'}->{'action'} ne 'use'){
			$key1 = $alerts{'dmidecode'}->{'action'};
			$val1 = $alerts{'dmidecode'}->{'message'};
			$key1 = ucfirst($key1);
		}
		else {
			$data = machine_data_dmi();
			if (%$data){
				machine_output($rows,$data);
			}
			elsif (!$key1){
				$key1 = 'Message';
				$val1 = main::message('machine-data');
			}
		}
	}
	elsif (!$fake{'elbrus'} && -d '/sys/class/dmi/id/'){
		$data = machine_data_sys();
		if (%$data){
			machine_output($rows,$data);
		}
		else {
			$key1 = 'Message';
			if ($alerts{'dmidecode'}->{'action'} eq 'missing'){
				$val1 = main::message('machine-data-dmidecode');
			}
			else {
				$val1 = main::message('machine-data');
			}
		}
	}
	elsif ($fake{'elbrus'} || $cpu_arch eq 'elbrus'){
		if ($fake{'elbrus'} || (my $program = main::check_program('fruid_print'))){
			$data = machine_data_fruid($program);
			if (%$data){
				machine_output($rows,$data);
			}
			elsif (!$key1){
				$key1 = 'Message';
				$val1 = main::message('machine-data-fruid');
			}
		}
	}
	elsif (!$bsd_type){
		# this uses /proc/cpuinfo so only GNU/Linux
		if (%risc){
			$data = machine_data_soc();
			machine_soc_output($rows,$data) if %$data;
		}
		if (!$data || !%$data){
			$key1 = 'Message';
			$val1 = main::message('machine-data-force-dmidecode','');
		}
	}
	# if error case, null data, whatever
	if ($key1){
		push(@$rows,{main::key($num++,0,1,$key1) => $val1,});
	}
	eval $end if $b_log;
	return $rows;
}

sub is_vm {
	return $b_vm;
}

## keys for machine data are:
# bios_vendor; bios_version; bios_date;
# board_name; board_serial; board_sku; board_vendor; board_version;
# product_name; product_version; product_serial; product_sku; product_uuid; 
# sys_vendor; 
## with extra data: 
# chassis_serial; chassis_type; chassis_vendor; chassis_version; 
## unused: bios_rev; bios_romsize; firmware type
sub machine_output {
	eval $start if $b_log;
	my ($rows,$data) = @_;
	my $firmware = 'BIOS';
	my $num = 0;
	my $j = 0;
	my ($b_chassis,$b_skip_chassis,$b_skip_system);
	my ($bios_date,$bios_rev,$bios_romsize,$bios_vendor,$bios_version,$chassis_serial,
	$chassis_type,$chassis_vendor,$chassis_version,$mobo_model,$mobo_serial,$mobo_vendor,
	$mobo_version,$product_name,$product_serial,$product_version,$system_vendor);
	#	foreach my $key (keys %data){
	#		print "$key: $data->{$key}\n";
	#	}
	if (!$data->{'sys_vendor'} || 
	($data->{'board_vendor'} && $data->{'sys_vendor'} eq $data->{'board_vendor'} && 
	!$data->{'product_name'} && !$data->{'product_version'} && 
	!$data->{'product_serial'})){
		$b_skip_system = 1;
	}
	# The goal here is to not show laptop/mobile devices
	# found a case of battery existing but having nothing in it on desktop mobo
	# not all laptops show the first. /proc/acpi/battery is deprecated.
	elsif (!glob('/proc/acpi/battery/*') && !glob('/sys/class/power_supply/*')){
		# ibm / ibm can be true; dell / quantum is false, so in other words, only do this
		# in case where the vendor is the same and the version is the same and not null, 
		# otherwise the version information is going to be different in all cases I think
		if (($data->{'sys_vendor'} && $data->{'board_vendor'} && 
		$data->{'sys_vendor'} eq $data->{'board_vendor'}) &&
		(($data->{'product_version'} && $data->{'board_version'} && 
		$data->{'product_version'} eq $data->{'board_version'}) ||
		(!$data->{'product_version'} && $data->{'product_name'} && $data->{'board_name'} && 
		$data->{'product_name'} eq $data->{'board_name'}))){
			$b_skip_system = 1;
		}
	}
	$data->{'device'} ||= 'N/A';
	$j = scalar @$rows;
	push(@$rows, {
	main::key($num++,0,1,'Type') => ucfirst($data->{'device'}),
	},);
	if (!$b_skip_system){
		# this has already been tested for above so we know it's not null
		$system_vendor = main::clean($data->{'sys_vendor'});
		$product_name = ($data->{'product_name'}) ? $data->{'product_name'}:'N/A';
		$product_version = ($data->{'product_version'}) ? $data->{'product_version'}:'N/A';
		$product_serial = main::filter($data->{'product_serial'});
		$rows->[$j]{main::key($num++,1,1,'System')} = $system_vendor;
		$rows->[$j]{main::key($num++,1,2,'product')} = $product_name;
		$rows->[$j]{main::key($num++,0,3,'v')} = $product_version;
		$rows->[$j]{main::key($num++,0,3,'serial')} = $product_serial;
		# no point in showing chassis if system isn't there, it's very unlikely that 
		# would be correct
		if ($extra > 1){
			if ($data->{'board_version'} && $data->{'chassis_version'} &&
			 $data->{'chassis_version'} eq $data->{'board_version'}){
				$b_skip_chassis = 1;
			}
			if (!$b_skip_chassis && $data->{'chassis_vendor'}){
				if ($data->{'chassis_vendor'} ne $data->{'sys_vendor'}){
					$chassis_vendor = $data->{'chassis_vendor'};
				}
				# dmidecode can have these be the same
				if ($data->{'chassis_type'} && $data->{'device'} ne $data->{'chassis_type'}){
					$chassis_type = $data->{'chassis_type'};
				}
				if ($data->{'chassis_version'}){
					$chassis_version = $data->{'chassis_version'};
					$chassis_version =~ s/^v([0-9])/$1/i;
				}
				$chassis_serial = main::filter($data->{'chassis_serial'});
				$chassis_vendor ||= '';
				$chassis_type ||= '';
				$rows->[$j]{main::key($num++,1,1,'Chassis')} = $chassis_vendor;
				if ($chassis_type){
					$rows->[$j]{main::key($num++,0,2,'type')} = $chassis_type;
				}
				if ($chassis_version){
					$rows->[$j]{main::key($num++,0,2,'v')} = $chassis_version;
				}
				$rows->[$j]{main::key($num++,0,2,'serial')} = $chassis_serial;
			}
		}
		$j++; # start new row
	}
	if ($data->{'firmware'}){
		$firmware = $data->{'firmware'};
	}
	$mobo_vendor = ($data->{'board_vendor'}) ? main::clean($data->{'board_vendor'}) : 'N/A';
	$mobo_model = ($data->{'board_name'}) ? $data->{'board_name'}: 'N/A';
	$mobo_version = ($data->{'board_version'})? $data->{'board_version'} : '';
	$mobo_serial = main::filter($data->{'board_serial'});
	$bios_vendor = ($data->{'bios_vendor'}) ? main::clean($data->{'bios_vendor'}) : 'N/A';
	if ($data->{'bios_version'}){
		$bios_version = $data->{'bios_version'};
		$bios_version =~ s/^v([0-9])/$1/i;
		if ($data->{'bios_rev'}){
			$bios_rev = $data->{'bios_rev'};
		}
	}
	$bios_version ||= 'N/A';
	if ($data->{'bios_date'}){
		$bios_date = $data->{'bios_date'};
	}
	$bios_date ||= 'N/A';
	if ($extra > 1 && $data->{'bios_romsize'}){
		$bios_romsize = $data->{'bios_romsize'};
	}
	$rows->[$j]{main::key($num++,1,1,'Mobo')} = $mobo_vendor;
	$rows->[$j]{main::key($num++,1,2,'model')} = $mobo_model;
	if ($mobo_version){
		$rows->[$j]{main::key($num++,0,3,'v')} = $mobo_version;
	}
	$rows->[$j]{main::key($num++,0,3,'serial')} = $mobo_serial;
	if ($extra > 1 && $data->{'product_sku'}){
		$rows->[$j]{main::key($num++,0,3,'part-nu')} = $data->{'product_sku'};
	}
	if (($show{'uuid'} || $extra > 2) && 
	($data->{'product_uuid'} || $data->{'board_uuid'})){
		my $uuid = ($data->{'product_uuid'}) ? $data->{'product_uuid'} : $data->{'board_uuid'};
		$uuid = main::filter($uuid,'filter-uuid');
		$rows->[$j]{main::key($num++,0,3,'uuid')} = $uuid;
	}
	if ($extra > 1 && $data->{'board_mfg_date'}){
		$rows->[$j]{main::key($num++,0,3,'mfg-date')} = $data->{'board_mfg_date'};
	}
	$rows->[$j]{main::key($num++,1,1,$firmware)} = $bios_vendor;
	$rows->[$j]{main::key($num++,0,2,'v')} = $bios_version;
	if ($bios_rev){
		$rows->[$j]{main::key($num++,0,2,'rev')} = $bios_rev;
	}
	$rows->[$j]{main::key($num++,0,2,'date')} = $bios_date;
	if ($bios_romsize){
		$rows->[$j]{main::key($num++,0,2,'rom size')} = $bios_romsize;
	}
	eval $end if $b_log;
}

sub machine_soc_output {
	my ($rows,$soc_machine) = @_;
	my ($key);
	my ($cont_sys,$ind_sys,$j,$num) = (1,1,0,0);
	# print Data::Dumper::Dumper \%soc_machine;
	# this is sketchy, /proc/device-tree/model may be similar to Hardware value from /proc/cpuinfo
	# raspi: Hardware	: BCM2835 model: Raspberry Pi Model B Rev 2
	if ($soc_machine->{'device'} || $soc_machine->{'model'}){
		$rows->[$j]{main::key($num++,0,1,'Type')} = uc($risc{'id'});
		my $system = 'System';
		if (defined $soc_machine->{'model'}){
			$rows->[$j]{main::key($num++,1,1,'System')} = $soc_machine->{'model'};
			$system = 'details';
			($cont_sys,$ind_sys) = (0,2);
		}
		$soc_machine->{'device'} ||= 'N/A';
		$rows->[$j]{main::key($num++,$cont_sys,$ind_sys,$system)} = $soc_machine->{'device'};
	}
	if ($soc_machine->{'mobo'}){
		$rows->[$j]{main::key($num++,1,1,'mobo')} = $soc_machine->{'mobo'};
	}
	# we're going to print N/A for 0000 values sine the item was there.
	if ($soc_machine->{'firmware'}){
		# most samples I've seen are like: 0000
		$soc_machine->{'firmware'} =~ s/^[0]+$//;
		$soc_machine->{'firmware'} ||= 'N/A';
		$rows->[$j]{main::key($num++,0,2,'rev')} = $soc_machine->{'firmware'};
	}
	# sometimes has value like: 0000
	if (defined $soc_machine->{'serial'}){
		# most samples I've seen are like: 0000
		$soc_machine->{'serial'} =~ s/^[0]+$//;
		$rows->[$j]{main::key($num++,0,2,'serial')} = main::filter($soc_machine->{'serial'});
	}
	eval $end if $b_log;
}

sub machine_data_fruid {
	eval $start if $b_log;
	my ($program) = @_;
	my ($b_start,$file,@fruid);
	my $data = {};
	if (!$fake{'elbrus'}){
		@fruid = main::grabber("$program 2>/dev/null",'','strip');
	}
	else {
		# $file = "$fake_data_dir/machine/elbrus/fruid/fruid-e801-1_full.txt";
		 $file = "$fake_data_dir/machine/elbrus/fruid/fruid-e804-1_full.txt";
		 @fruid = main::reader($file,'strip');
	}
	foreach (@fruid){
		$b_start = 1 if /^Board info/;
		next if !$b_start;
		my @split = split(/\s*:\s+/,$_,2);
		if ($split[0] eq 'Mfg. Date/Time'){
			$data->{'board_mfg_date'} = $split[1];
			$data->{'board_mfg_date'} =~ s/^(\d+:\d+)\s//;
		}
		elsif ($split[0] eq 'Board manufacturer'){
			$data->{'board_vendor'} = $split[1];
		}
		elsif ($split[0] eq 'Board part number'){
			$data->{'product_sku'} = $split[1];
		}
		elsif ($split[0] eq 'Board product name'){
			$data->{'board_name'} = $split[1];
			if ($split[1] =~ /(SWTX|^EL)/){
				$data->{'device'} = 'server';
			}
			elsif ($split[1] =~ /(PC$)/){
				$data->{'device'} = 'desktop';
			}
		}
		elsif ($split[0] eq 'Board serial number'){
			$data->{'board_serial'} = $split[1];
		}
		elsif ($split[0] eq 'Board product version'){
			$data->{'board_version'} = $split[1];
		}
	}
	if (%$data){
		$data->{'bios_vendor'} = 'MCST';
		$data->{'firmware'} = 'Boot';
	}
	if ($dbg[28]){
		print 'fruid: $data: ', Data::Dumper::Dumper $data;
		print 'fruid: @fruid: ', Data::Dumper::Dumper \@fruid;
	}
	if ($b_log){
		main::log_data('dump','@fruid',\@fruid);
		main::log_data('dump','%data',$data);
	}
	if ($fake{'elbrus'} || -e '/proc/bootdata'){
		machine_data_bootdata($data);
	}
	eval $end if $b_log;
	return $data;
}

# Note: fruid should get device, extra data here uuid, mac
# Field names map to dmi/sys names.
# args: 0: $data hash ref;
sub machine_data_bootdata {
	eval $start if $b_log;
	my ($b_pairs,@bootdata,$file);
	if (!$fake{'elbrus'}){
		 @bootdata = main::reader('/proc/bootdata','strip');
	}
	else {
		# $file = "$fake_data_dir/machine/elbrus/bootdata/e2c3/desktop-e2c3.txt";
		# $file = "$fake_data_dir/machine/elbrus/bootdata/e4c/server-e4c-x4-1.txt";
		 $file = "$fake_data_dir/machine/elbrus/bootdata/e4c/server-e4c-x4-2.txt";
		# $file = "$fake_data_dir/machine/elbrus/bootdata/e8c/desktop-e8c.txt";
		# $file = "$fake_data_dir/machine/elbrus/bootdata/e8c/server-e8c-x4-1.txt";
		# $file = "$fake_data_dir/machine/elbrus/bootdata/e8c/server-e8c-x4-2.txt";
		# $file = "$fake_data_dir/machine/elbrus/bootdata/e8c2/desktop-e8c2.txt";
		# $file = "$fake_data_dir/machine/elbrus/bootdata/e8c2/server-e8c2-4x.txt";
		# $file = "$fake_data_dir/machine/elbrus/bootdata/e8c2/server-e8c2.txt";
		# $file = "$fake_data_dir/machine/elbrus/bootdata/e16c/server-e16c-1.txt";
		# $file = "$fake_data_dir/machine/elbrus/bootdata/e16c/server-e16c-2.txt";
		# $file = "$fake_data_dir/machine/elbrus/bootdata/e16c/server-e16c-3.txt";
		 @bootdata = main::reader($file,'strip');
	}
	foreach (@bootdata){
		s/\s\s+/ /g; # spaces not consistent
		my @line = split(/=/,$_,2);
		# These only positive IDs, unreliable data source
		if ($line[1]){
			$line[1] =~ s/'//g;
			$line[0] = lc($line[0]);
			if ($line[0] eq 'mb_type'){
				# unknown: unknown (0x0); 
				if ($line[1] =~ /([\/-]SWT|^EL)/){
					$_[0]->{'device'} = 'server';
				}
				elsif ($line[1] =~ /([\/-]PC)/){
					$_[0]->{'device'} = 'desktop';
				}
			}
			elsif ($line[0] eq 'uuid'){
				$_[0]->{'product_uuid'} = $line[1];
			}
			# fruid has mac address too, but in 0x.. form, this one is easier to read
			elsif ($line[0] eq 'mac'){
				$_[0]->{'board_mac'} = $line[1];
			}
		}
		else {
			if (/release-([\d\.A-Z-]+).*?\srevision\s([\d\.A-Z-]+)/i){
				$_[0]->{'bios_version'} = $1;
				$_[0]->{'bios_rev'} = $2;
			}
			elsif (/built\son\s(\S+\s\d+\s\d+)\b/){
				$_[0]->{'bios_date'} = $1;
			}
		}
	}
	if ($dbg[28]){
		print 'bootdata: $data: ', Data::Dumper::Dumper $_[0];
		print 'bootdata: @bootdata: ', Data::Dumper::Dumper \@bootdata;
	}
	if ($b_log){
		main::log_data('dump','@bootdata',\@bootdata);
		main::log_data('dump','%data', $_[0]);
		eval $end;
	}
	eval $end if $b_log;
}

sub machine_data_sys {
	eval $start if $b_log;
	my ($path,$vm);
	my $data = {};
	my $sys_dir = '/sys/class/dmi/id/';
	my $sys_dir_alt = '/sys/devices/virtual/dmi/id/';
	my @sys_files = qw(bios_vendor bios_version bios_date 
	board_name board_serial board_vendor board_version chassis_type 
	product_name product_serial product_sku product_uuid product_version 
	sys_vendor
	);
	if ($extra > 1){
		splice(@sys_files, 0, 0, qw(chassis_serial chassis_vendor chassis_version));
	}
	$data->{'firmware'} = 'BIOS';
	# print Data::Dumper::Dumper \@sys_files;
	if (!-d $sys_dir){
		if (-d $sys_dir_alt){
			$sys_dir = $sys_dir_alt;
		}
		else {
			return 0;
		}
	}
	if (-d '/sys/firmware/efi'){
		$data->{'firmware'} = 'UEFI';
	}
	elsif (glob('/sys/firmware/acpi/tables/UEFI*')){
		$data->{'firmware'} = 'UEFI-[Legacy]';
	}
	foreach (@sys_files){
		$path = "$sys_dir$_";
		if (-r $path){
			$data->{$_} = main::reader($path,'',0);
			$data->{$_} = ($data->{$_}) ? main::clean_dmi($data->{$_}) : '';
		}
		elsif (!$b_root && -e $path && !-r $path){
			$data->{$_} = main::message('root-required');
		}
		else {
			$data->{$_} = '';
		}
	}
	if ($data->{'chassis_type'}){
		if ($data->{'chassis_type'} == 1){
			$data->{'device'} = check_vm($data->{'sys_vendor'},$data->{'product_name'});
			$data->{'device'} ||= 'other-vm?';
		}
		else {
			$data->{'device'} = get_device_sys($data->{'chassis_type'});
		}
	}
	#	print "sys:\n";
	#	foreach (keys %data){
	#		print "$_: $data->{$_}\n";
	#	}
	print Data::Dumper::Dumper $data if $dbg[28];
	main::log_data('dump','%data',$data) if $b_log;
	eval $end if $b_log;
	return $data;
}

# This will create an alternate machine data source
# which will be used for alt ARM machine data in cases 
# where no dmi data present, or by cpu data to guess at 
# certain actions for arm only.
sub machine_data_soc {
	eval $end if $b_log;
	my $data = {};
	if (my $file = $system_files{'proc-cpuinfo'}){
		CpuItem::cpuinfo_data_grabber($file) if !$loaded{'cpuinfo'};
		# grabber sets keys to lower case to avoid error here
		if ($cpuinfo_machine{'hardware'} || $cpuinfo_machine{'machine'}){
			$data->{'device'} = main::get_defined($cpuinfo_machine{'hardware'},
			 $cpuinfo_machine{'machine'});
			$data->{'device'} = main::clean_arm($data->{'device'});
			$data->{'device'} = main::clean_dmi($data->{'device'});
			$data->{'device'} = main::clean($data->{'device'});
		}
		if (defined $cpuinfo_machine{'system type'} || $cpuinfo_machine{'model'}){
			$data->{'model'} = main::get_defined($cpuinfo_machine{'system type'},
			 $cpuinfo_machine{'model'});
			$data->{'model'} = main::clean_dmi($data->{'model'});
			$data->{'model'} = main::clean($data->{'model'});
		}
		# seen with PowerMac PPC
		if (defined $cpuinfo_machine{'motherboard'}){
			$data->{'mobo'} = $cpuinfo_machine{'motherboard'};
		}
		if (defined $cpuinfo_machine{'revision'}){
			$data->{'firmware'} = $cpuinfo_machine{'revision'};
		}
		if (defined $cpuinfo_machine{'serial'}){
			$data->{'serial'} = $cpuinfo_machine{'serial'};
		}
		undef %cpuinfo_machine; # we're done with it, don't need it anymore
	}
	if (!$data->{'model'} && $b_android){
		main::set_build_prop() if !$loaded{'build-prop'};
		if ($build_prop{'product-manufacturer'} && $build_prop{'product-model'}){
			my $brand = '';
			if ($build_prop{'product-brand'} && 
			 $build_prop{'product-brand'} ne $build_prop{'product-manufacturer'}){ 
				$brand = $build_prop{'product-brand'} . ' ';
			}
			$data->{'model'} = $brand . $build_prop{'product-manufacturer'} . ' ' . $build_prop{'product-model'};
		}
		elsif ($build_prop{'product-device'}){
			$data->{'model'} = $build_prop{'product-device'};
		}
		elsif ($build_prop{'product-name'}){
			$data->{'model'} = $build_prop{'product-name'};
		}
	}
	if (!$data->{'model'} && -r '/proc/device-tree/model'){
		my $model  = main::reader('/proc/device-tree/model','',0);
		main::log_data('data',"device-tree-model: $model") if $b_log;
		if ($model){
			$model = main::clean_dmi($model);
			$model = (split(/\x01|\x02|\x03|\x00/, $model))[0] if $model;
			my $device_temp = main::clean_regex($data->{'device'});
			if (!$data->{'device'} || ($model && $model !~ /\Q$device_temp\E/i)){
				$model = main::clean_arm($model);
				$data->{'model'} = $model;
			}
		}
	}
	if (!$data->{'serial'} && -f '/proc/device-tree/serial-number'){
		my $serial  = main::reader('/proc/device-tree/serial-number','',0);
		$serial = (split(/\x01|\x02|\x03|\x00/, $serial))[0] if $serial;
		main::log_data('data',"device-tree-serial: $serial") if $b_log;
		$data->{'serial'} = $serial if $serial;
	}
	print Data::Dumper::Dumper $data if $dbg[28];
	main::log_data('dump','%data',$data) if $b_log;
	eval $end if $b_log;
	return $data;
}

# bios_date: 09/07/2010
# bios_romsize: dmi only
# bios_vendor: American Megatrends Inc.
# bios_version: P1.70
# bios_rev: 8.14:  dmi only
# board_name: A770DE+
# board_serial: 
# board_vendor: ASRock
# board_version: 
# chassis_serial: 
# chassis_sku:
# chassis_type: 3
# chassis_vendor: 
# chassis_version: 
# firmware: 
# product_name: 
# product_serial: 
# product_sku: 
# product_uuid: 
# product_version: 
# uuid: dmi/sysctl only, map to product_uuid
# sys_vendor:
sub machine_data_dmi {
	eval $start if $b_log;
	return if !@dmi;
	my ($vm);
	my $data = {};
	$data->{'firmware'} = 'BIOS';
	# dmi types:
	# 0 bios; 1 system info; 2 board|base board info; 3 chassis info; 
	# 4 processor info, use to check for hypervisor
	foreach my $row (@dmi){
		# bios/firmware
		if ($row->[0] == 0){
			# skip first three row, we don't need that data
			foreach my $item (@$row[3 .. $#$row]){
				if ($item !~ /^~/){ # skip the indented rows
					my @value = split(/:\s+/, $item);
					if ($value[0] eq 'Release Date'){
						$data->{'bios_date'} = main::clean_dmi($value[1]) }
					elsif ($value[0] eq 'Vendor'){
						$data->{'bios_vendor'} = main::clean_dmi($value[1]) }
					elsif ($value[0] eq 'Version'){
						$data->{'bios_version'} = main::clean_dmi($value[1]) }
					elsif ($value[0] eq 'ROM Size'){
						$data->{'bios_romsize'} = main::clean_dmi($value[1]) }
					elsif ($value[0] eq 'BIOS Revision'){
						$data->{'bios_rev'} = main::clean_dmi($value[1]) }
				}
				else {
					if ($item eq '~UEFI is supported'){
						$data->{'firmware'} = 'UEFI';}
				}
			}
			next;
		}
		# system information
		elsif ($row->[0] == 1){
			# skip first three row, we don't need that data
			foreach my $item (@$row[3 .. $#$row]){
				if ($item !~ /^~/){ # skip the indented rows
					my @value = split(/:\s+/, $item);
					if ($value[0] eq 'Product Name'){
						$data->{'product_name'} = main::clean_dmi($value[1]) }
					elsif ($value[0] eq 'Version'){
						$data->{'product_version'} = main::clean_dmi($value[1]) }
					elsif ($value[0] eq 'Serial Number'){
						$data->{'product_serial'} = main::clean_dmi($value[1]) }
					elsif ($value[0] eq 'Manufacturer'){
						$data->{'sys_vendor'} = main::clean_dmi($value[1]) }
					elsif ($value[0] eq 'SKU Number'){
						$data->{'product_sku'} = main::clean_dmi($value[1]) }
					elsif ($value[0] eq 'UUID'){
						$data->{'product_uuid'} = main::clean_dmi($value[1]) }
				}
			}
			next;
		}
		# baseboard information
		elsif ($row->[0] == 2){
			# skip first three row, we don't need that data
			foreach my $item (@$row[3 .. $#$row]){
				if ($item !~ /^~/){ # skip the indented rows
					my @value = split(/:\s+/, $item);
					if ($value[0] eq 'Product Name'){
						$data->{'board_name'} = main::clean_dmi($value[1]) }
					elsif ($value[0] eq 'Serial Number'){
						$data->{'board_serial'} = main::clean_dmi($value[1]) }
					elsif ($value[0] eq 'Manufacturer'){
						$data->{'board_vendor'} = main::clean_dmi($value[1]) }
					elsif ($value[0] eq 'Version'){
						$data->{'board_version'} = main::clean_dmi($value[1]) }
				}
			}
			next;
		}
		# chassis information
		elsif ($row->[0] == 3){
			# skip first three row, we don't need that data
			foreach my $item (@$row[3 .. $#$row]){
				if ($item !~ /^~/){ # skip the indented rows
					my @value = split(/:\s+/, $item);
					if ($value[0] eq 'Serial Number'){
						$data->{'chassis_serial'} = main::clean_dmi($value[1]) }
					# not sure if this sku is same as system sku
					elsif ($value[0] eq 'SKU Number'){
						$data->{'chassis_sku'} = main::clean_dmi($value[1]) }
					elsif ($value[0] eq 'Type'){
						$data->{'chassis_type'} = main::clean_dmi($value[1]) }
					elsif ($value[0] eq 'Manufacturer'){
						$data->{'chassis_vendor'} = main::clean_dmi($value[1]) }
					elsif ($value[0] eq 'Version'){
						$data->{'chassis_version'} = main::clean_dmi($value[1]) }
				}
			}
			if ($data->{'chassis_type'} && $data->{'chassis_type'} ne 'Other'){
				$data->{'device'} = $data->{'chassis_type'};
			}
			next;
		}
		# this may catch some BSD and fringe Linux cases
		# processor information: check for hypervisor
		elsif ($row->[0] == 4){
			# skip first three row, we don't need that data
			if (!$data->{'device'}){
				if (grep {/hypervisor/i} @$row){
					$data->{'device'} = 'virtual-machine';
					$b_vm = 1;
				}
			}
			last;
		}
		elsif ($row->[0] > 4){
			last;
		}
	}
	if (!$data->{'device'}){
		$data->{'device'} = check_vm($data->{'sys_vendor'},$data->{'product_name'});
		$data->{'device'} ||= 'other-vm?';
	}
	#	print "dmi:\n";
	#	foreach (keys %data){
	#		print "$_: $data->{$_}\n";
	#	}
	print Data::Dumper::Dumper $data if $dbg[28];
	main::log_data('dump','%data',$data) if $b_log;
	eval $end if $b_log;
	return $data;
}

# As far as I know, only OpenBSD supports this method.
# it uses hw. info from sysctl -a and bios info from dmesg.boot
sub machine_data_sysctl {
	eval $start if $b_log;
	my ($product,$vendor,$vm);
	my $data = {};
	# ^hw\.(vendor|product|version|serialno|uuid)
	foreach (@{$sysctl{'machine'}}){
		next if !$_;
		my @item = split(':', $_);
		next if !$item[1];
		if ($item[0] eq 'hw.vendor' || $item[0] eq 'machdep.dmi.board-vendor'){
			$data->{'board_vendor'} = main::clean_dmi($item[1]);
		}
		elsif ($item[0] eq 'hw.product' || $item[0] eq 'machdep.dmi.board-product'){
			$data->{'board_name'} = main::clean_dmi($item[1]);
		}
		elsif ($item[0] eq 'hw.version' || $item[0] eq 'machdep.dmi.board-version'){
			$data->{'board_version'} = main::clean_dmi($item[1]);
		}
		elsif ($item[0] eq 'hw.serialno' || $item[0] eq 'machdep.dmi.board-serial'){
			$data->{'board_serial'} = main::clean_dmi($item[1]);
		}
		elsif ($item[0] eq 'hw.serial'){
			$data->{'board_serial'} = main::clean_dmi($item[1]);
		}
		elsif ($item[0] eq 'hw.uuid'){
			$data->{'board_uuid'} = main::clean_dmi($item[1]);
		}
		elsif ($item[0] eq 'machdep.dmi.system-vendor'){
			$data->{'sys_vendor'} = main::clean_dmi($item[1]);
		}
		elsif ($item[0] eq 'machdep.dmi.system-product'){
			$data->{'product_name'} = main::clean_dmi($item[1]);
		}
		elsif ($item[0] eq 'machdep.dmi.system-version'){
			$data->{'product_version'} = main::clean_dmi($item[1]);
		}
		elsif ($item[0] eq 'machdep.dmi.system-serial'){
			$data->{'product_serial'} = main::clean_dmi($item[1]);
		}
		elsif ($item[0] eq 'machdep.dmi.system-uuid'){
			$data->{'product_uuid'} = main::clean_dmi($item[1]);
		}
		# bios0:at mainbus0: AT/286+ BIOS, date 06/30/06, BIOS32 rev. 0 @ 0xf2030, SMBIOS rev. 2.4 @ 0xf0000 (47 entries)
		# bios0:vendor Phoenix Technologies, LTD version "3.00" date 06/30/2006
		elsif ($item[0] =~ /^bios[0-9]/){
			if ($_ =~ /^^bios[0-9]:at\s.*?\srev\.\s([\S]+)\s@.*/){
				$data->{'bios_rev'} = $1;
				$data->{'firmware'} = 'BIOS' if $_ =~ /BIOS/;
			}
			elsif ($item[1] =~ /^vendor\s(.*?)\sversion\s(.*?)\sdate\s([\S]+)/){
				$data->{'bios_vendor'} = $1;
				$data->{'bios_version'} = $2;
				$data->{'bios_date'} = $3;
				$data->{'bios_version'} =~ s/^v//i if $data->{'bios_version'} && $data->{'bios_version'} !~ /vi/i;
			}
		}
		elsif ($item[0] eq 'machdep.dmi.bios-vendor'){
			$data->{'bios_vendor'} = main::clean_dmi($item[1]);
		}
		elsif ($item[0] eq 'machdep.dmi.bios-version'){
			$data->{'bios_version'} = main::clean_dmi($item[1]);
		}
		elsif ($item[0] eq 'machdep.dmi.bios-date'){
			$data->{'bios_date'} = main::clean_dmi($item[1]);
		}
	}
	if ($data->{'board_vendor'} || $data->{'sys_vendor'} || $data->{'board_name'} || $data->{'product_name'}){
		$vendor = $data->{'sys_vendor'};
		$vendor = $data->{'board_vendor'} if !$vendor;
		$product = $data->{'product_name'};
		$product = $data->{'board_name'} if !$product;
	}
	# detections can be from other sources.
	$data->{'device'} = check_vm($vendor,$product);
	print Data::Dumper::Dumper $data if $dbg[28];
	main::log_data('dump','%data',$data) if $b_log;
	eval $end if $b_log;
	return $data;
}

sub get_device_sys {
	eval $start if $b_log;
	my ($chasis_id) = @_;
	my ($device) = ('');
	my @chassis;
	# See inxi-resources MACHINE DATA for data sources
	$chassis[2] = 'unknown';
	$chassis[3] = 'desktop';
	$chassis[4] = 'desktop';
	# 5 - pizza box was a 1 U desktop enclosure, but some old laptops also id this way
	$chassis[5] = 'pizza-box';
	$chassis[6] = 'desktop';
	$chassis[7] = 'desktop';
	$chassis[8] = 'portable';
	$chassis[9] = 'laptop';
	# note: lenovo T420 shows as 10, notebook,  but it's not a notebook
	$chassis[10] = 'laptop';
	$chassis[11] = 'portable';
	$chassis[12] = 'docking-station';
	# note: 13 is all-in-one which we take as a mac type system
	$chassis[13] = 'desktop';
	$chassis[14] = 'notebook';
	$chassis[15] = 'desktop';
	$chassis[16] = 'laptop';
	$chassis[17] = 'server';
	$chassis[18] = 'expansion-chassis';
	$chassis[19] = 'sub-chassis';
	$chassis[20] = 'bus-expansion';
	$chassis[21] = 'peripheral';
	$chassis[22] = 'RAID';
	$chassis[23] = 'server';
	$chassis[24] = 'desktop';
	$chassis[25] = 'multimount-chassis'; # blade?
	$chassis[26] = 'compact-PCI';
	$chassis[27] = 'blade';
	$chassis[28] = 'blade';
	$chassis[29] = 'blade-enclosure';
	$chassis[30] = 'tablet';
	$chassis[31] = 'convertible';
	$chassis[32] = 'detachable';
	$chassis[33] = 'IoT-gateway';
	$chassis[34] = 'embedded-pc';
	$chassis[35] = 'mini-pc';
	$chassis[36] = 'stick-pc';
	$device = $chassis[$chasis_id] if $chassis[$chasis_id];
	eval $end if $b_log;
	return $device;
}

sub check_vm {
	eval $start if $b_log;
	my ($manufacturer,$product_name) = @_;
	$manufacturer ||= '';
	$product_name ||= '';
	my $vm;
	if (my $program = main::check_program('systemd-detect-virt')){
		my $vm_test = (main::grabber("$program 2>/dev/null"))[0];
		if ($vm_test){
			# kvm vbox reports as oracle, usually, unless they change it
			if (lc($vm_test) eq 'oracle'){
				$vm = 'virtualbox';
			}
			elsif ($vm_test ne 'none'){
				$vm = $vm_test;
			}
		}
	}
	if (!$vm || lc($vm) eq 'bochs'){
		if (-e '/proc/vz'){$vm = 'openvz'}
		elsif (-e '/proc/xen'){$vm = 'xen'}
		elsif (-e '/dev/vzfs'){$vm = 'virtuozzo'}
		elsif (my $program = main::check_program('lsmod')){
			my @vm_data = main::grabber("$program 2>/dev/null");
			if (@vm_data){
				if (grep {/kqemu/i} @vm_data){$vm = 'kqemu'}
				elsif (grep {/kvm|qumranet/i} @vm_data){$vm = 'kvm'}
				elsif (grep {/qemu/i} @vm_data){$vm = 'qemu'}
			}
		}
	}
	# this will catch many Linux systems and some BSDs
	if (!$vm || lc($vm) eq 'bochs'){
		# $device_vm is '' if nothing detected
		my @vm_data = ($device_vm);
		push(@vm_data,@{$dboot{'machine-vm'}}) if $dboot{'machine-vm'};
		if (-e '/dev/disk/by-id'){
			my @dev = glob('/dev/disk/by-id/*');
			push(@vm_data,@dev);
		}
		if (grep {/innotek|vbox|virtualbox/i} @vm_data){
			$vm = 'virtualbox';
		}
		elsif (grep {/vmware/i} @vm_data){
			$vm = 'vmware';
		}
		# needs to be first, because contains virtio;qumranet, grabber only gets 
		# first instance then stops, so make sure patterns are right.
		elsif (grep {/(openbsd[\s-]vmm)/i} @vm_data){
			$vm = 'vmm';
		}
		elsif (grep {/(\bhvm\b)/i} @vm_data){
			$vm = 'hvm';
		}
		elsif (grep {/(qemu)/i} @vm_data){
			$vm = 'qemu';
		}
		elsif (grep {/(\bkvm\b|qumranet|virtio)/i} @vm_data){
			$vm = 'kvm';
		}
		elsif (grep {/Virtual HD|Microsoft.*Virtual Machine/i} @vm_data){
			$vm = 'hyper-v';
		}
		if (!$vm && (my $file = $system_files{'proc-cpuinfo'})){
			my @info = main::reader($file);
			$vm = 'virtual-machine' if grep {/^flags.*hypervisor/} @info;
		}
		# this may be wrong, confirm it
		if (!$vm && -e '/dev/vda' || -e '/dev/vdb' || -e '/dev/xvda' || -e '/dev/xvdb'){
			$vm = 'virtual-machine';
		}
	}
	if (!$vm && $product_name){
		if ($product_name eq 'VMware'){
			$vm = 'vmware';
		}
		elsif ($product_name eq 'VirtualBox'){
			$vm = 'virtualbox';
		}
		elsif ($product_name eq 'KVM'){
			$vm = 'kvm';
		}
		elsif ($product_name eq 'Bochs'){
			$vm = 'qemu';
		}
	}
	if (!$vm && $manufacturer && $manufacturer eq 'Xen'){
		$vm = 'xen';
	}
	$b_vm = 1 if $vm;
	eval $end if $b_log;
	return $vm;
}
}

## NetworkItem 
{