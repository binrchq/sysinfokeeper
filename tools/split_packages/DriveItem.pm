package DriveItem;
my ($b_hddtemp,$b_nvme,$smartctl_missing,$vendors);
my ($hddtemp,$nvme) = ('','');
my (@by_id,@by_path);
my ($debugger_dir);
# main::writer("$debugger_dir/system-repo-data-urpmq.txt",\@data2) if $debugger_dir;

sub get {
	eval $start if $b_log;
	my ($type) = @_;
	$type ||= 'standard';
	my ($key1,$val1);
	my $rows = [];
	my $num = 0;
	my $data = drive_data($type);
	# NOTE: 
	if (@$data){
		if ($type eq 'standard'){
			storage_output($rows,$data);
			drive_output($rows,$data) if $show{'disk'};
			if ($bsd_type && !$dboot{'disk'} && $type eq 'standard' && $show{'disk'}){
				$key1 = 'Drive Report';
				my $file = $system_files{'dmesg-boot'};
				if ($file && ! -r $file){
					$val1 = main::message('dmesg-boot-permissions');
				}
				elsif (!$file){
					$val1 = main::message('dmesg-boot-missing');
				}
				else {
					$val1 = main::message('disk-data-bsd');
				}
				push(@$rows,{main::key($num++,0,1,$key1) => $val1,});
			}
		}
		# used by short form, raw data returned
		else {
			$rows = $data;
			# print Data::Dumper::Dumper $rows;
		}
	}
	else {
		$key1 = 'Message';
		$val1 = main::message('disk-data');
		@$rows = ({main::key($num++,0,1,$key1) => $val1});
	}
	if (!@$rows){
		$key1 = 'Message';
		$val1 = main::message('disk-data');
		@$rows = ({main::key($num++,0,1,$key1) => $val1});
	}
	# push(@rows,@data);
	if ($show{'optical'} || $show{'optical-basic'}){
		OpticalItem::get($rows);
	}
	($b_hddtemp,$b_nvme,$hddtemp,$nvme,$vendors) = ();
	(@by_id,@by_path) = ();
	eval $end if $b_log;
	return $rows;
}

sub storage_output {
	eval $start if $b_log;
	my ($rows,$disks) = @_;
	my ($num,$j) = (0,0);
	my ($size,$size_value,$used) = ('','','');
	push(@$rows, {
	main::key($num++,1,1,'Local Storage') => '',
	});
	# print Data::Dumper::Dumper $disks;
	$size = main::get_size($disks->[0]{'size'},'string','N/A');
	if ($disks->[0]{'logical-size'}){
		$rows->[$j]{main::key($num++,1,2,'total')} = '';
		$rows->[$j]{main::key($num++,0,3,'raw')} = $size;
		$size = main::get_size($disks->[0]{'logical-size'},'string');
		$size_value = $disks->[0]{'logical-size'};
		# print Data::Dumper::Dumper $disks;
		$rows->[$j]{main::key($num++,1,3,'usable')} = $size;
	}
	else {
		$size_value = $disks->[0]{'size'} if $disks->[0]{'size'};
		$rows->[$j]{main::key($num++,0,2,'total')} = $size;
	}
	$used = main::get_size($disks->[0]{'used'},'string','N/A');
	if ($extra > 0 && $disks->[0]{'logical-free'}){
		$size = main::get_size($disks->[0]{'logical-free'},'string');
		$rows->[$j]{main::key($num++,0,4,'lvm-free')} = $size;
	}
	if (($size_value && $size_value =~ /^[0-9]/) && 
		 ($used && $disks->[0]{'used'} =~ /^[0-9]/)){
		$used = $used . ' (' . sprintf("%0.1f", $disks->[0]{'used'}/$size_value*100) . '%)';
	}
	$rows->[$j]{main::key($num++,0,2,'used')} = $used;
	shift @$disks;
	eval $end if $b_log;
}

sub drive_output {
	eval $start if $b_log;
	my ($rows,$disks) = @_;
	# print Data::Dumper::Dumper $disks;
	my ($b_smart_permissions,$block,$smart_age,$smart_basic,$smart_fail);
	my ($num,$j) = (0,0);
	my ($id,$model,$size) = ('','','');
	# note: specific smartctl non-missing errors handled inside loop
	if ($smartctl_missing){
		$j = scalar @$rows;
		$rows->[$j]{main::key($num++,0,1,'SMART Message')} = $smartctl_missing;
	}
	elsif ($b_admin){
		my $result = smartctl_fields();
		($smart_age,$smart_basic,$smart_fail) = @$result;
	}
	foreach my $row (sort { $a->{'id'} cmp $b->{'id'} } @$disks){
		($id,$model,$size) = ('','','');
		$num = 1;
		$model = ($row->{'model'}) ? $row->{'model'}: 'N/A';
		$id =  ($row->{'id'}) ? "/dev/$row->{'id'}":'N/A';
		$size = ($row->{'size'}) ? main::get_size($row->{'size'},'string') : 'N/A';
		# print Data::Dumper::Dumper $disks;
		$j = scalar @$rows;
		if (!$b_smart_permissions && $row->{'smart-permissions'}){
			$b_smart_permissions = 1;
			$rows->[$j]{main::key($num++,0,1,'SMART Message')} = $row->{'smart-permissions'};
			$j = scalar @$rows;
		}
		push(@$rows, {
		main::key($num++,1,1,'ID') => $id,
		});
		if ($b_admin && $row->{'maj-min'}){
			$rows->[$j]{main::key($num++,0,2,'maj-min')} = $row->{'maj-min'};
		}
		
		if ($row->{'vendor'}){
			$rows->[$j]{main::key($num++,0,2,'vendor')} = $row->{'vendor'};
		}
		$rows->[$j]{main::key($num++,0,2,'model')} = $model;
		if ($row->{'drive-vendor'}){
			$rows->[$j]{main::key($num++,0,2,'drive vendor')} = $row->{'drive-vendor'};
		}
		if ($row->{'drive-model'}){
			$rows->[$j]{main::key($num++,0,2,'drive model')} = $row->{'drive-model'};
		}
		if ($row->{'family'}){
			$rows->[$j]{main::key($num++,0,2,'family')} = $row->{'family'};
		}
		$rows->[$j]{main::key($num++,0,2,'size')} = $size;
		if ($b_admin && $row->{'block-physical'}){
			$rows->[$j]{main::key($num++,1,2,'block-size')} = '';
			$rows->[$j]{main::key($num++,0,3,'physical')} = "$row->{'block-physical'} B";
			$block = ($row->{'block-logical'}) ? "$row->{'block-logical'} B" : 'N/A';
			$rows->[$j]{main::key($num++,0,3,'logical')} = $block;
		}
		if ($row->{'type'}){
			$rows->[$j]{main::key($num++,1,2,'type')} = $row->{'type'};
			if ($extra > 1 && $row->{'type'} eq 'USB' && $row->{'abs-path'} && 
			$usb{'disk'}){
				foreach my $device (@{$usb{'disk'}}){
					if ($device->[8] && $device->[26] && 
					$row->{'abs-path'} =~ /^$device->[26]/){
						$rows->[$j]{main::key($num++,0,3,'rev')} = $device->[8];
						if ($device->[17]){
							$rows->[$j]{main::key($num++,0,3,'spd')} = $device->[17];
						}
						if ($device->[24]){
							$rows->[$j]{main::key($num++,0,3,'lanes')} = $device->[24];
						}
						if ($b_admin && $device->[22]){
							$rows->[$j]{main::key($num++,0,3,'mode')} = $device->[22];
						}
						last;
					}
				}
			}
		}
		if ($extra > 1 && $row->{'speed'}){
			if ($row->{'sata'}){
				$rows->[$j]{main::key($num++,0,2,'sata')} = $row->{'sata'};
			}
			$rows->[$j]{main::key($num++,0,2,'speed')} = $row->{'speed'};
			$rows->[$j]{main::key($num++,0,2,'lanes')} = $row->{'lanes'} if $row->{'lanes'};
		}
		if ($extra > 2){
			$row->{'tech'} ||= 'N/A';
			$rows->[$j]{main::key($num++,1,2,'tech')} = $row->{'tech'};
			if ($row->{'rotation'}){
				$rows->[$j]{main::key($num++,0,2,'rpm')} = $row->{'rotation'};
			}
		}
		if ($extra > 1){
			if (!$row->{'serial'} && $alerts{'bioctl'} && 
			 $alerts{'bioctl'}->{'action'} eq 'permissions'){
				$row->{'serial'} = main::message('root-required');
			}
			else {
				$row->{'serial'} = main::filter($row->{'serial'});
			}
			$rows->[$j]{main::key($num++,0,2,'serial')} = $row->{'serial'};
			if ($row->{'drive-serial'}){
				$rows->[$j]{main::key($num++,0,2,'drive serial')} = main::filter($row->{'drive-serial'});
			}
			if ($row->{'firmware'}){
				$rows->[$j]{main::key($num++,0,2,'fw-rev')} = $row->{'firmware'};
			}
			if ($row->{'drive-firmware'}){
				$rows->[$j]{main::key($num++,0,2,'drive-rev')} = $row->{'drive-firmware'};
			}
		}
		if ($extra > 0 && $row->{'temp'}){
			$rows->[$j]{main::key($num++,0,2,'temp')} = $row->{'temp'} . ' C';
		}
		if ($extra > 1 && $alerts{'bioctl'}){
			if (!$row->{'duid'} && $alerts{'bioctl'}->{'action'} eq 'permissions'){
				$rows->[$j]{main::key($num++,0,2,'duid')} = main::message('root-required');
			}
			elsif ($row->{'duid'}){
				$rows->[$j]{main::key($num++,0,2,'duid')} = main::filter($row->{'duid'});
			}
		}
		# Extra level tests already done
		if (defined $row->{'partition-table'}){
			$rows->[$j]{main::key($num++,0,2,'scheme')} = $row->{'partition-table'};
		}
		if ($row->{'smart'} || $row->{'smart-error'}){
			$j = scalar @$rows;
			## Basic SMART and drive info ##
			smart_output('basic',$smart_basic,$row,$j,\$num,$rows);
			## Old-Age errors ##
			smart_output('age',$smart_age,$row,$j,\$num,$rows);
			## Pre-Fail errors ##
			smart_output('fail',$smart_fail,$row,$j,\$num,$rows);
		}
	}
	eval $end if $b_log;
}

# args: $num and $rows passed by reference
sub smart_output {
	eval $start if $b_log;
	my ($type,$smart_data,$row,$j,$num,$rows) = @_;
	my ($b_found);
	my ($l,$m,$p) = ($type eq 'basic') ? (2,3,0) : (3,4,0);
	my ($m_h,$p_h) = ($m,$p);
	for (my $i = 0; $i < scalar @$smart_data;$i++){
		if ($row->{$smart_data->[$i][0]}){
			if (!$b_found){
				my ($key,$support) = ('','');
				if ($type eq 'basic'){
					$support = ($row->{'smart'}) ? $row->{'smart'}: $row->{'smart-error'};
					$key = $smart_data->[$i][1];
				}
				elsif ($type eq 'age'){$key = 'Old-Age';}
				elsif ($type eq 'fail'){$key = 'Pre-Fail';}
				$rows->[$j]{main::key($$num++,1,$l,$key)} = $support;
				$b_found = 1;
				next if $type eq 'basic';
			}
			if ($type ne 'basic'){
				if ($smart_data->[$i][0] =~ /-a[vr]?$/){
					($p,$m) = (1,$m_h);
				}
				elsif ($smart_data->[$i][0] =~ /-[ftvw]$/){
					($p,$m) = (0,5);
				}
				else {
					($p,$m) = ($p_h,$m_h);
				}
			}
			$rows->[$j]{main::key($$num++,$p,$m,$smart_data->[$i][1])} = $row->{$smart_data->[$i][0]};
		}
	}
	eval $end if $b_log;
}

sub drive_data {
	eval $start if $b_log;
	my ($type) = @_;
	my ($data,@devs);
	my $num = 0;
	my ($used) = (0);
	PartitionItem::set_partitions() if !$loaded{'set-partitions'};
	RaidItem::raid_data() if !$loaded{'raid'};
	# see docs/inxi-partitions.txt > FILE SYSTEMS for more on remote/fuse fs
	my $fs_skip = PartitionItem::get_filters('fs-exclude');
	foreach my $row (@partitions){
		# don't count remote/distributed/union type fs towards used
		next if ($row->{'fs'} && $row->{'fs'} =~ /^$fs_skip$/);
		# don't count non partition swap
		next if ($row->{'swap-type'} && $row->{'swap-type'} ne 'partition');
		# in some cases, like redhat, mounted cdrom/dvds show up in partition data
		next if ($row->{'dev-base'} && $row->{'dev-base'} =~ /^sr[0-9]+$/);
		# this is used for specific cases where bind, or incorrect multiple mounts 
		# to same partitions, or btrfs sub volume mounts, is present. The value is 
		# searched for an earlier appearance of that partition and if it is present, 
		# the data is not added into the partition used size.
		if ($row->{'dev-base'} !~ /^(\/\/|:\/)/ && !(grep {/$row->{'dev-base'}/} @devs)){
			$used += $row->{'used'} if $row->{'used'};
			push(@devs, $row->{'dev-base'});
		}
	}
	if (!$bsd_type){
		$data = proc_data($used);
	}
	else {
		$data = bsd_data($used);
	}
	if ($b_admin){
		if ($alerts{'smartctl'} && $alerts{'smartctl'}->{'action'} eq 'use'){
			smartctl_data($data);
		}
		else {
			$smartctl_missing = $alerts{'smartctl'}->{'message'};
		}
	}
	print Data::Dumper::Dumper $data if $dbg[13];
	main::log_data('data',"used: $used") if $b_log;
	eval $end if $b_log;
	return $data;
}

sub proc_data {
	eval $start if $b_log;
	my ($used) = @_;
	my (@drives);
	my ($b_hdx,$logical_size,$size) = (0,0,0);
	PartitionData::set() if !$bsd_type && !$loaded{'partition-data'};
	foreach my $row (@proc_partitions){
		if ($row->[-1] =~ /^(fio[a-z]+|[hsv]d[a-z]+|(ada|mmcblk|n[b]?d|nvme[0-9]+n)[0-9]+)$/){
			$b_hdx = 1 if $row->[-1] =~ /^hd[a-z]/;
			push(@drives, {
			'firmware' => '',
			'id' => $row->[-1],
			'maj-min' => $row->[0] . ':' . $row->[1],
			'model' => '',
			'serial' => '',
			'size' => $row->[2],
			'spec' => '',
			'speed' => '',
			'temp' => '',
			'type' => '',
			'vendor' => '',
			});
		}
		# See http://lanana.org/docs/device-list/devices-2.6+.txt for major numbers used below
		# See https://www.mjmwired.net/kernel/Documentation/devices.txt for kernel 4.x device numbers
		# if ($row->[0] =~ /^(3|22|33|8)$/ && $row->[1] % 16 == 0)  {
		#	 $size += $row->[2];
		# }
		# special case from this data: 8     0  156290904 sda
		# 43        0   48828124 nbd0
		# note: known starters: vm: 252/253/254; grsec: 202; nvme: 259 mmcblk: 179
		# Note: with > 1 nvme drives, the minor number no longer passes the modulus tests,
		# It appears to just increase randomly from the first 0 minor of the first nvme to 
		# nvme partitions to next nvme, so it only passes the test for the first nvme drive.
		# note: 66       16 9766436864 sdah ; 65      240 9766436864 sdaf[maybe special case when double letters?
		# Check /proc/devices for major number matches
		if ($row->[0] =~ /^(3|8|22|33|43|6[5-9]|7[12]|12[89]|13[0-5]|179|202|252|253|254|259)$/ && 
		 $row->[-1] =~ /(mmcblk[0-9]+|n[b]?d[0-9]+|nvme[0-9]+n[0-9]+|fio[a-z]+|[hsv]d[a-z]+)$/ && 
		 ($row->[1] % 16 == 0 || $row->[1] % 16 == 8 || $row->[-1] =~ /(nvme[0-9]+n[0-9]+)$/)){
			$size += $row->[2];
		}
	}
	# raw_logical[0] is total of all logical raid/lvm found
	# raw_logical[1] is total of all components found. If this totally fails,
	# and we end up with raw logical less than used, give up
	if (@raw_logical && $raw_logical[0] && (!$used || $raw_logical[0] > $used)){
		$logical_size = ($size - $raw_logical[1] + $raw_logical[0]);
	}
	# print Data::Dumper::Dumper \@drives;
	main::log_data('data',"size: $size") if $b_log;
	my $result = [{
	'logical-size' => $logical_size,
	'logical-free' => $raw_logical[2],
	'size' => $size,
	'used' => $used,
	}];
	# print Data::Dumper::Dumper \@data;
	if ($show{'disk'}){
		unshift(@drives,@$result);
		# print 'drives:', Data::Dumper::Dumper \@drives;
		$result = proc_data_advanced($b_hdx,\@drives);
	}
	main::log_data('dump','@$result',$result) if $b_log;
	print Data::Dumper::Dumper $result if $dbg[24];
	eval $end if $b_log;
	return $result;
}

sub proc_data_advanced {
	eval $start if $b_log;
	my ($b_hdx,$drives) = @_;
	my ($i) = (0);
	my ($disk_data,$scsi,@temp,@working);
	my ($pt_cmd) = ('unset');
	my ($block_type,$file,$firmware,$model,$path,
	$partition_scheme,$serial,$vendor,$working_path);
	@by_id = main::globber('/dev/disk/by-id/*');
	# these do not contain any useful data, no serial or model name
	# wwn-0x50014ee25fb50fc1 and nvme-eui.0025385b71b07e2e 
	# scsi-SATA_ST980815A_ simply repeats ata-ST980815A_; same with scsi-0ATA_WDC_WD5000L31X
	# we also don't need the partition items
	my $pattern = '^\/dev\/disk\/by-id\/(md-|lvm-|dm-|wwn-|nvme-eui|raid-|scsi-([0-9]ATA|SATA))|-part[0-9]+$';
	@by_id = grep {!/$pattern/} @by_id if @by_id;
	# print join("\n", @by_id), "\n";
	@by_path = main::globber('/dev/disk/by-path/*');
	## check for all ide type drives, non libata, only do it if hdx is in array
	## this is now being updated for new /sys type paths, this may handle that ok too
	## skip the first rows in the loops since that's the basic size/used data
	if ($b_hdx){
		for ($i = 1; $i < scalar @$drives; $i++){
			$file = "/proc/ide/$drives->[$i]{'id'}/model";
			if ($drives->[$i]{'id'} =~ /^hd[a-z]/ && -e $file){
				$model = main::reader($file,'strip',0);
				$drives->[$i]{'model'} = $model;
			}
		}
	}
	# scsi stuff
	if ($file = $system_files{'proc-scsi'}){
		$scsi = scsi_data($file);
	}
	# print 'drives:', Data::Dumper::Dumper $drives;
	for ($i = 1; $i < scalar @$drives; $i++){
		#next if $drives->[$i]{'id'} =~ /^hd[a-z]/;
		($block_type,$firmware,$model,$partition_scheme,
		$serial,$vendor,$working_path) = ('','','','','','','');
		# print "$drives->[$i]{'id'}\n";
		$disk_data = disk_data_by_id("/dev/$drives->[$i]{'id'}");
		main::log_data('dump','@$disk_data', $disk_data) if $b_log;
		if ($drives->[$i]{'id'} =~ /[sv]d[a-z]/){
			$block_type = 'sdx';
			$working_path = "/sys/block/$drives->[$i]{'id'}/device/";
		}
		elsif ($drives->[$i]{'id'} =~ /mmcblk/){
			$block_type = 'mmc';
			$working_path = "/sys/block/$drives->[$i]{'id'}/device/";
		}
		elsif ($drives->[$i]{'id'} =~ /nvme/){
			$block_type = 'nvme';
			# this results in:
			# /sys/devices/pci0000:00/0000:00:03.2/0000:06:00.0/nvme/nvme0/nvme0n1
			# but we want to go one level down so slice off trailing nvme0n1
			$working_path = Cwd::abs_path("/sys/block/$drives->[$i]{'id'}");
			$working_path =~ s/nvme[^\/]*$//;
		}
		if ($working_path){
			$drives->[$i]{'abs-path'} = Cwd::abs_path($working_path);
		}
		main::log_data('data',"working path: $working_path") if $b_log;
		if ($b_admin && -e "/sys/block/"){
			($drives->[$i]{'block-logical'},$drives->[$i]{'block-physical'}) = @{block_data($drives->[$i]{'id'})};
		}
		if ($block_type && $scsi && @$scsi && @by_id && ! -e "${working_path}model" && 
		! -e "${working_path}name"){
			## ok, ok, it's incomprehensible, search /dev/disk/by-id for a line that contains the
			# discovered disk name AND ends with the correct identifier, sdx
			# get rid of whitespace for some drive names and ids, and extra data after - in name
			SCSI:
			foreach my $row (@$scsi){
				if ($row->{'model'}){
					$row->{'model'} = (split(/\s*-\s*/,$row->{'model'}))[0];
					foreach my $id (@by_id){
						if ($id =~ /$row->{'model'}/ && "/dev/$drives->[$i]{'id'}" eq Cwd::abs_path($id)){
							$drives->[$i]{'firmware'} = $row->{'firmware'};
							$drives->[$i]{'model'} = $row->{'model'};
							$drives->[$i]{'vendor'} = $row->{'vendor'};
							last SCSI;
						}
					}
				}
			}
		}
		# note: an entire class of model names gets truncated by /sys so that should be the last 
		# in priority re tests.
		elsif ((!@$disk_data || !$disk_data->[0]) && $block_type){
			# NOTE: while path ${working_path}vendor exists, it contains junk value, like: ATA
			$path = "${working_path}model";
			if (-r $path){
				$model = main::reader($path,'strip',0);
				$drives->[$i]{'model'} = $model if $model;
			}
			elsif ($block_type eq 'mmc' && -r "${working_path}name"){
				$path = "${working_path}name";
				$model = main::reader($path,'strip',0);
				$drives->[$i]{'model'} = $model if $model;
			}
		}
		if (!$drives->[$i]{'model'} && @$disk_data){
			$drives->[$i]{'model'} = $disk_data->[0] if $disk_data->[0];
			$drives->[$i]{'vendor'} = $disk_data->[1] if $disk_data->[1];
		}
		# maybe rework logic if find good scsi data example, but for now use this
		elsif ($drives->[$i]{'model'} && !$drives->[$i]{'vendor'}){
			$drives->[$i]{'model'} = main::clean_disk($drives->[$i]{'model'});
			my $result = disk_vendor($drives->[$i]{'model'},'');
			$drives->[$i]{'model'} = $result->[1] if $result->[1];
			$drives->[$i]{'vendor'} = $result->[0] if $result->[0];
		}
		if ($working_path){
			$path = "${working_path}removable";
			if (-r $path && main::reader($path,'strip',0)){
				$drives->[$i]{'type'} = 'Removable' ; # 0/1 value
			}
		}
		my $peripheral = peripheral_data($drives->[$i]{'id'});
		# note: we only want to update type if we found a peripheral, otherwise preserve value
		$drives->[$i]{'type'} = $peripheral if $peripheral;
		# print "type:$drives->[$i]{'type'}\n";
		if ($extra > 0){
			$drives->[$i]{'temp'} = hdd_temp("$drives->[$i]{'id'}");
			if ($extra > 1){
				my $speed_data = drive_speed($drives->[$i]{'id'});
				# only assign if defined / not 0
				$drives->[$i]{'speed'} = $speed_data->[0] if $speed_data->[0];
				$drives->[$i]{'lanes'} = $speed_data->[1] if $speed_data->[1];
				if (@$disk_data && $disk_data->[2]){
					$drives->[$i]{'serial'} = $disk_data->[2];
				}
				else {
					$path = "${working_path}serial";
					if (-r $path){
						$serial = main::reader($path,'strip',0);
						$drives->[$i]{'serial'} = $serial if $serial;
					}
				}
				if ($extra > 2 && !$drives->[$i]{'firmware'}){
					my @fm = ('rev','fmrev','firmware_rev'); # 0 ~ default; 1 ~ mmc; 2 ~ nvme
					foreach my $firmware (@fm){
						$path = "${working_path}$firmware";
						if (-r $path){
							$drives->[$i]{'firmware'} = main::reader($path,'strip',0);
							last;
						}
					}
				}
			}
		}
		if ($extra > 2){
			my $result = disk_data_advanced($pt_cmd,$drives->[$i]{'id'});
			$pt_cmd = $result->[0];
			$drives->[$i]{'partition-table'} = uc($result->[1]) if $result->[1];
			if ($result->[2]){
				$drives->[$i]{'rotation'} = $result->[2];
				$drives->[$i]{'tech'} = 'HDD';
			}
			elsif (($block_type && $block_type ne 'sdx') ||
			# note: this case could conceivabley be wrong for a spun down HDD
			(defined $result->[2] && $result->[2] eq '0') ||
			($drives->[$i]{'model'} && 
			$drives->[$i]{'model'} =~ /(flash|mmc|msata|\bm[\.-]?2\b|nvme|ssd|solid\s?state)/i)){
				$drives->[$i]{'tech'} = 'SSD';
			}
		}
	}
	main::log_data('dump','$drives',$drives) if $b_log;
	print Data::Dumper::Dumper $drives if $dbg[24];
	eval $end if $b_log;
	return $drives;
}

# camcontrol identify <device> |grep ^serial (this might be (S)ATA specific)
# smartcl -i <device> |grep ^Serial
# see smartctl; camcontrol devlist; gptid status;
sub bsd_data {
	eval $start if $b_log;
	my ($used) = @_;
	my (@drives,@softraid,@temp);
	my ($i,$logical_size,$size,$working) = (0,0,0,0);
	my $file = $system_files{'dmesg-boot'};
	DiskDataBSD::set() if !$loaded{'disk-data-bsd'};
	# we don't want non dboot disk data from gpart or disklabel
	if ($file && ! -r $file){
		$size = main::message('dmesg-boot-permissions');
	}
	elsif (!$file){
		$size = main::message('dmesg-boot-missing');
	}
	elsif (%disks_bsd){
		if ($sysctl{'softraid'}){
			@softraid = map {$_ =~ s/.*\(([^\)]+)\).*/$1/;$_} @{$sysctl{'softraid'}};
		}
		foreach my $id (sort keys %disks_bsd){
			next if !$disks_bsd{$id} || !$disks_bsd{$id}->{'size'};
			$drives[$i]->{'id'} = $id;
			$drives[$i]->{'firmware'} = '';
			$drives[$i]->{'temp'} = '';
			$drives[$i]->{'type'} = '';
			$drives[$i]->{'vendor'} = '';
			$drives[$i]->{'block-logical'} = $disks_bsd{$id}->{'block-logical'};
			$drives[$i]->{'block-physical'} = $disks_bsd{$id}->{'block-physical'};
			$drives[$i]->{'partition-table'} = $disks_bsd{$id}->{'scheme'};
			$drives[$i]->{'serial'} = $disks_bsd{$id}->{'serial'};
			$drives[$i]->{'size'} = $disks_bsd{$id}->{'size'};
			# don't count OpenBSD RAID/CRYPTO virtual disks!
			if ($drives[$i]->{'size'} && (!@softraid || !(grep {$id eq $_} @softraid))){
				$size += $drives[$i]->{'size'} if $drives[$i]->{'size'};
			}
			$drives[$i]->{'spec'} = $disks_bsd{$id}->{'spec'};
			$drives[$i]->{'speed'} = $disks_bsd{$id}->{'speed'};
			$drives[$i]->{'type'} = $disks_bsd{$id}->{'type'};
			# generate the synthetic model/vendor data
			$drives[$i]->{'model'} = $disks_bsd{$id}->{'model'};
			if ($drives[$i]->{'model'}){
				my $result = disk_vendor($drives[$i]->{'model'},'');
				$drives[$i]->{'vendor'} = $result->[0] if $result->[0];
				$drives[$i]->{'model'} = $result->[1] if $result->[1];
			}
			if ($disks_bsd{$id}->{'duid'}){
				$drives[$i]->{'duid'} = $disks_bsd{$id}->{'duid'};
			}
			if ($disks_bsd{$id}->{'partition-table'}){
				$drives[$i]->{'partition-table'} = $disks_bsd{$id}->{'partition-table'};
			}
			$i++;
		}
		# raw_logical[0] is total of all logical raid/lvm found
		# raw_logical[1] is total of all components found. If this totally fails,
		# and we end up with raw logical less than used, give up
		if (@raw_logical && $size && $raw_logical[0] && 
		 (!$used || $raw_logical[0] > $used)){
			$logical_size = ($size - $raw_logical[1] + $raw_logical[0]);
		}
		if (!$size){
			$size = main::message('data-bsd');
		}
	}
	my $result = [{
	'logical-size' => $logical_size,
	'logical-free' => $raw_logical[2],
	'size' => $size,
	'used' => $used,
	}];
	#main::log_data('dump','$data',\@data) if $b_log;
	if ($show{'disk'}){
		push(@$result,@drives);
		# print 'data:', Data::Dumper::Dumper \@data;
	}
	main::log_data('dump','$result',$result) if $b_log;
	print Data::Dumper::Dumper $result if $dbg[24];
	eval $end if $b_log;
	return $result;
}

# return indexes: 0 - age; 1 - basic; 2 - fail
# make sure to update if fields added in smartctl_data()
sub smartctl_fields {
	eval $start if $b_log;
	my $data = [
	[ # age
	['smart-gsense-error-rate-ar','g-sense error rate'],
	['smart-media-wearout-a','media wearout'],
	['smart-media-wearout-t','threshold'],
	['smart-media-wearout-f','alert'],
	['smart-multizone-errors-av','write error rate'],
	['smart-multizone-errors-t','threshold'],
	['smart-udma-crc-errors-ar','UDMA CRC errors'],
	['smart-udma-crc-errors-f','alert'],
	],
	[ # basic
	['smart','SMART'],
	['smart-error','SMART Message'],
	['smart-support','state'],
	['smart-status','health'],
	['smart-power-on-hours','on'],
	['smart-cycles','cycles'],
	['smart-units-read','read-units'],
	['smart-units-written','written-units'],
	['smart-read','read'],
	['smart-written','written'],
	],
	[ # fail
	['smart-end-to-end-av','end-to-end'],
	['smart-end-to-end-t','threshold'],
	['smart-end-to-end-f','alert'],
	['smart-raw-read-error-rate-av','read error rate'],
	['smart-raw-read-error-rate-t','threshold'],
	['smart-raw-read-error-rate-f','alert'],
	['smart-reallocated-sectors-av','reallocated sector'],
	['smart-reallocated-sectors-t','threshold'],
	['smart-reallocated-sectors-f','alert'],
	['smart-retired-blocks-av','retired block'],
	['smart-retired-blocks-t','threshold'],
	['smart-retired-blocks-f','alert'],
	['smart-runtime-bad-block-av','runtime bad block'],
	['smart-runtime-bad-block-t','threshold'],
	['smart-runtime-bad-block-f','alert'],
	['smart-seek-error-rate-av', 'seek error rate'],
	['smart-seek-error-rate-t', 'threshold'],
	['smart-seek-error-rate-f', 'alert'],
	['smart-spinup-time-av','spin-up time'],
	['smart-spinup-time-t','threshold'],
	['smart-spinup-time-f','alert'],
	['smart-ssd-life-left-av','life left'],
	['smart-ssd-life-left-t','threshold'],
	['smart-ssd-life-left-f','alert'],
	['smart-unused-reserve-block-av','unused reserve block'],
	['smart-unused-reserve-block-t','threshold'],
	['smart-unused-reserve-block-f','alert'],
	['smart-used-reserve-block-av','used reserve block'],
	['smart-used-reserve-block-t','threshold'],
	['smart-used-reserve-block-f','alert'],
	['smart-unknown-1-a','attribute'],
	['smart-unknown-1-v','value'],
	['smart-unknown-1-w','worst'],
	['smart-unknown-1-t','threshold'],
	['smart-unknown-1-f','alert'],
	['smart-unknown-2-a','attribute'],
	['smart-unknown-2-v','value'],
	['smart-unknown-2-w','worst'],
	['smart-unknown-2-t','threshold'],
	['smart-unknown-2-f','alert'],
	['smart-unknown-3-a','attribute'],
	['smart-unknown-3-v','value'],
	['smart-unknown-3-w','worst'],
	['smart-unknown-3-t','threshold'],
	['smart-unknown-4-f','alert'],
	['smart-unknown-4-a','attribute'],
	['smart-unknown-4-v','value'],
	['smart-unknown-4-w','worst'],
	['smart-unknown-4-t','threshold'],
	['smart-unknown-4-f','alert'],
	['smart-unknown-5-f','alert'],
	['smart-unknown-5-a','attribute'],
	['smart-unknown-5-v','value'],
	['smart-unknown-5-w','worst'],
	['smart-unknown-5-t','threshold'],
	['smart-unknown-5-f','alert'],
	]
	];
	eval $end if $b_log;
	return $data;
}

sub smartctl_data {
	eval $start if $b_log;
	my ($data) = @_;
	my ($b_attributes,$b_intel,$b_kingston,$cmd,%holder,$id,@working,@result,@split);
	my ($splitter,$num,$a,$f,$r,$t,$v,$w,$y) = (':\s*',0,0,8,1,5,3,4,6); # $y is type, $t threshold, etc
	for (my $i = 0; $i < scalar @$data; $i++){
		next if !$data->[$i]{'id'};
		($b_attributes,$b_intel,$b_kingston,$splitter,$num,$a,$r) = (0,0,0,':\s*',0,0,1);
		%holder = ();
		# print $data->[$i]{'id'},"\n";
		# m2 nvme failed on nvme0n1 drive id:
		$id = $data->[$i]{'id'};
		$id =~ s/n[0-9]+$// if $id =~ /^nvme/;
		# openbsd needs the 'c' partition, which is the entire disk
		$id .= 'c' if $bsd_type && $bsd_type eq 'openbsd';
		$cmd = $alerts{'smartctl'}->{'path'} . " -AHi /dev/" . $id . ' 2>/dev/null';
		@result = main::grabber($cmd, '', 'strip');
		main::log_data('dump','@result', \@result) if $b_log; # log before cleanup
		@result = grep {!/^(smartctl|Copyright|==)/} @result;
		print 'Drive:/dev/' . $id . ":\n", Data::Dumper::Dumper\@result if $dbg[12];
		if (scalar @result < 5){
			if (grep {/failed: permission denied/i} @result){
				$data->[$i]{'smart-permissions'} = main::message('tool-permissions','smartctl');
			}
			elsif (grep {/unknown usb bridge/i} @result){
				$data->[$i]{'smart-error'} = main::message('smartctl-usb');
			}
			# can come later in output too
			elsif (grep {/A mandatory SMART command failed/i} @result){
				$data->[$i]{'smart-error'} = main::message('smartctl-command');
			}
			elsif (grep {/open device.*Operation not supported by device/i} @result){
				$data->[$i]{'smart-error'} = main::message('smartctl-open');
			}
			else {
				$data->[$i]{'smart-error'} = main::message('tool-unknown-error','smartctl');
			}
			next;
		}
		else {
			foreach my $row (@result){
				if ($row =~ /^ID#/){
					$splitter = '\s+';
					$b_attributes = 1;
					$a = 1;
					$r = 9;
					next;
				}
				@split = split(/$splitter/, $row);
				next if !$b_attributes && ! defined $split[$r];
				# some cases where drive not in db threshhold will be: ---
				# value is usually 0 padded which confuses perl. However this will
				# make subsequent tests easier, and will strip off leading 0s
				if ($b_attributes){
					$split[$t] = (main::is_numeric($split[$t])) ? int($split[$t]) : 0;
					$split[$v] = (main::is_numeric($split[$v])) ? int($split[$v]) : 0;
				}
				# can occur later in output so retest it here
				if ($split[$a] =~ /A mandatory SMART command failed/i){
					$data->[$i]{'smart-error'} = main::message('smartctl-command');
				}
				## DEVICE INFO ##
				if ($split[$a] eq 'Device Model'){
					$b_intel = 1 if $split[$r] =~/\bintel\b/i;
					$b_kingston = 1 if $split[$r] =~/kingston/i;
					# usb/firewire/thunderbolt enclosure id method
					if ($data->[$i]{'type'}){
						my $result = disk_vendor("$split[$r]");
						if ($data->[$i]{'model'} && $data->[$i]{'model'} ne $result->[1]){
							$data->[$i]{'drive-model'} = $result->[1];
						}
						if ($data->[$i]{'vendor'} && $data->[$i]{'vendor'} ne $result->[0]){
							$data->[$i]{'drive-vendor'} = $result->[0];
						}
					}
					# fallback for very corner cases where primary model id failed
					if (!$data->[$i]{'model'} && $split[$r]){
						my $result = disk_vendor("$split[$r]");
						$data->[$i]{'model'} = $result->[1] if $result->[1];
						$data->[$i]{'vendor'} = $result->[0] if $result->[0] && !$data->[$i]{'vendor'};
					}
				}
				elsif ($split[$a] eq 'Model Family'){
					my $result = disk_vendor("$split[$r]");
					$data->[$i]{'family'} = $result->[1] if $result->[1];
					# $data->[$i]{'family'} =~ s/$data->[$i]{'vendor'}\s*// if $data->[$i]{'vendor'};
				}
				elsif ($split[$a] eq 'Firmware Version'){
					# 01.01A01 vs 1A01
					if ($data->[$i]{'firmware'} && $split[$r] !~ /$data->[$i]{'firmware'}/){
						$data->[$i]{'drive-firmware'} = $split[$r];
					}
					elsif (!$data->[$i]{'firmware'}){
						$data->[$i]{'firmware'} = $split[$r];
					}
				}
				elsif ($split[$a] eq 'Rotation Rate'){
					if ($split[$r] !~ /^Solid/){
						$data->[$i]{'rotation'} = $split[$r];
						$data->[$i]{'rotation'} =~ s/\s*rpm$//i;
						$data->[$i]{'tech'} = 'HDD';
					}
					else {
						$data->[$i]{'tech'} = 'SSD';
					}
				}
				elsif ($split[$a] eq 'Serial Number'){
					if (!$data->[$i]{'serial'}){
						$data->[$i]{'serial'} = $split[$r];
					}
					elsif ($data->[$i]{'type'} && $split[$r] ne $data->[$i]{'serial'}){
						$data->[$i]{'drive-serial'} = $split[$r];
					}
				}
				elsif ($split[$a] eq 'SATA Version is'){
					if ($split[$r] =~ /SATA ([0-9.]+), ([0-9.]+ [^\s]+)(\(current: ([1-9.]+ [^\s]+)\))?/){
						$data->[$i]{'sata'} = $1;
						$data->[$i]{'speed'} = $2 if !$data->[$i]{'speed'};
					}
				}
				# seen both Size and Sizes. Linux will usually have both, BSDs not physical
				elsif ($split[$a] =~ /^Sector Sizes?$/){
					if ($data->[$i]{'type'} || !$data->[$i]{'block-logical'} || !$data->[$i]{'block-physical'}){
						if ($split[$r] =~ m|^([0-9]+) bytes logical/physical|){
							$data->[$i]{'block-logical'} = $1;
							$data->[$i]{'block-physical'} = $1;
						}
						# 512 bytes logical, 4096 bytes physical
						elsif ($split[$r] =~ m|^([0-9]+) bytes logical, ([0-9]+) bytes physical|){
							$data->[$i]{'block-logical'} = $1;
							$data->[$i]{'block-physical'} = $2;
						}
					}
				}
				## SMART STATUS/HEALTH ##
				elsif ($split[$a] eq 'SMART support is'){
					if ($split[$r] =~ /^(Available|Unavailable) /){
						$data->[$i]{'smart'} = $1;
						$data->[$i]{'smart'} = ($data->[$i]{'smart'} eq 'Unavailable') ? 'no' : 'yes';
					}
					elsif ($split[$r] =~ /^(Enabled|Disabled)/){
						$data->[$i]{'smart-support'} = lc($1);
					}
				}
				elsif ($split[$a] eq 'SMART overall-health self-assessment test result'){
					$data->[$i]{'smart-status'} = $split[$r];
					# seen nvme that only report smart health, not smart support
					$data->[$i]{'smart'} = 'yes' if !$data->[$i]{'smart'};
				}
				
				## DEVICE CONDITION: temp/read/write/power on/cycles ##
				# Attributes data fields, sometimes are same syntax as info block:...
				elsif ($split[$a] eq 'Power_Cycle_Count' || $split[$a] eq 'Power Cycles'){
					$data->[$i]{'smart-cycles'} = $split[$r] if $split[$r];
				}
				elsif ($split[$a] eq 'Power_On_Hours' || $split[$a] eq 'Power On Hours' ||
				 $split[$a] eq 'Power_On_Hours_and_Msec'){
					if ($split[$r]){
						$split[$r] =~ s/,//;
						# trim off: h+0m+00.000s which is useless and at times empty anyway
						$split[$r] =~ s/h\+.*$// if $split[$a] eq 'Power_On_Hours_and_Msec';
						# $split[$r] = 43;
						if ($split[$r] =~ /^([0-9]+)$/){
							if ($1 > 9000){
								$data->[$i]{'smart-power-on-hours'} = int($1/(24*365)) . 'y ' . int($1/24)%365 . 'd ' . $1%24 . 'h';
							}
							elsif ($1 > 100){
								$data->[$i]{'smart-power-on-hours'} = int($1/24) . 'd ' . $1%24 . 'h';
							}
							else {
								$data->[$i]{'smart-power-on-hours'} = $split[$r] . ' hrs';
							}
						}
						else {
							$data->[$i]{'smart-power-on-hours'} = $split[$r];
						}
					}
				}
				# 'Airflow_Temperature_Cel' like: 29 (Min/Max 14/43) so can't use -1 index
				# Temperature like 29 Celsisu
				elsif ($split[$a] eq 'Temperature_Celsius' || $split[$a] eq 'Temperature' ||
				$split[$a] eq 'Airflow_Temperature_Cel'){
					if (!$data->[$i]{'temp'} && $split[$r]){
						$data->[$i]{'temp'} = $split[$r];
					}
				}
				## DEVICE USE: Reads/Writes ##
				elsif ($split[$a] eq 'Data Units Read'){
					$data->[$i]{'smart-units-read'} = $split[$r];
				}
				elsif ($split[$a] eq 'Data Units Written'){
					$data->[$i]{'smart-units-written'} = $split[$r];
				}
				elsif ($split[$a] eq 'Host_Reads_32MiB'){
					$split[$r] = $split[$r] * 32 * 1024;
					$data->[$i]{'smart-read'} = main::get_size($split[$r],'string');
				}
				elsif ($split[$a] eq 'Host_Writes_32MiB'){
					$split[$r] = $split[$r] * 32 * 1024;
					$data->[$i]{'smart-written'} = main::get_size($split[$r],'string');
				}
				elsif ($split[$a] eq 'Lifetime_Reads_GiB'){
					$data->[$i]{'smart-read'} = $split[$r] . ' GiB';
				}
				elsif ($split[$a] eq 'Lifetime_Writes_GiB'){
					$data->[$i]{'smart-written'} = $split[$r] . ' GiB';
				}
				elsif ($split[$a] eq 'Total_LBAs_Read'){
					if (main::is_numeric($split[$r])){
						# blocks in bytes, so convert to KiB, the internal unit here
						# reports in 32MiB units, sigh
						if ($b_intel){
							$split[$r] = $split[$r] * 32 * 1024;
						}
						# reports in 1 GiB units, sigh
						elsif ($b_kingston){
							$split[$r] = $split[$r] * 1024 * 1024;
						}
						# rare fringe cases, cygwin run as user, block size will not be found
						# this is what it's supposed to refer to
						elsif ($data->[$i]{'block-logical'}) {
							$split[$r] = int($data->[$i]{'block-logical'} * $split[$r] / 1024);
						}
						if ($b_intel || $b_kingston || $data->[$i]{'block-logical'}){
							$data->[$i]{'smart-read'} = main::get_size($split[$r],'string');
						}
					}
				}
				elsif ($split[$a] eq 'Total_LBAs_Written'){
					if (main::is_numeric($split[$r]) && $data->[$i]{'block-logical'}){
						# blocks in bytes, so convert to KiB, the internal unit here
						# reports in 32MiB units, sigh
						if ($b_intel){
							$split[$r] = $split[$r] * 32 * 1024;
						}
						# reports in 1 GiB units, sigh
						elsif ($b_kingston){
							$split[$r] = $split[$r] * 1024 * 1024;
						}
						# rare fringe cases, cygwin run as user, block size will not be found
						# this is what it's supposed to refer to, in byte blocks
						elsif ($data->[$i]{'block-logical'}) {
							$split[$r] = int($data->[$i]{'block-logical'} * $split[$r] / 1024);
						}
						if ($b_intel || $b_kingston || $data->[$i]{'block-logical'}){
							$data->[$i]{'smart-written'} = main::get_size($split[$r],'string');
						}
					}
				}
				## DEVICE OLD AGE ##
				# 191 G-Sense_Error_Rate 0x0032 001 001 000 Old_age Always - 291
				elsif ($split[$a] eq 'G-Sense_Error_Rate'){
					# $data->[$i]{'smart-media-wearout'} = $split[$r];
					if ($b_attributes && $split[$r] > 100){
						$data->[$i]{'smart-gsense-error-rate-ar'} = $split[$r];
					}
				}
				elsif ($split[$a] eq 'Media_Wearout_Indicator'){
					# $data->[$i]{'smart-media-wearout'} = $split[$r];
					# seen case where they used hex numbers because values
					# were in 47 billion range in hex. You can't hand perl an unquoted
					# hex number that is > 2^32 without tripping a perl warning
					if ($b_attributes && $split[$r] && !main::is_hex("$split[$r]") && $split[$r] > 0){
						$data->[$i]{'smart-media-wearout-av'} = $split[$v];
						$data->[$i]{'smart-media-wearout-t'} = $split[$t];
						$data->[$i]{'smart-media-wearout-f'} = $split[$f] if $split[$f] ne '-';
					}
				}
				elsif ($split[$a] eq 'Multi_Zone_Error_Rate'){
					# note: all t values are 0 that I have seen
					if (($split[$v] - $split[$t]) < 50){
						$data->[$i]{'smart-multizone-errors-av'} = $split[$v];
						$data->[$i]{'smart-multizone-errors-t'} = $split[$v];
					}
					
				}
				elsif ($split[$a] eq 'UDMA_CRC_Error_Count'){
					if (main::is_numeric($split[$r]) && $split[$r] > 50){
						$data->[$i]{'smart-udma-crc-errors-ar'} = $split[$r];
						$data->[$i]{'smart-udma-crc-errors-f'} = main::message('smartctl-udma-crc') if $split[$r] > 500;
					}
				}
				
				## DEVICE PRE-FAIL ##
				elsif ($split[$a] eq 'Available_Reservd_Space'){
					# $data->[$i]{'smart-available-reserved-space'} = $split[$r];
					if ($b_attributes && $split[$v] && $split[$t] && $split[$t]/$split[$v] > 0.92){
						$data->[$i]{'smart-available-reserved-space-av'} = $split[$v];
						$data->[$i]{'smart-available-reserved-space-t'} = $split[$t];
						$data->[$i]{'smart-available-reserved-space-f'} = $split[$f] if $split[$f] ne '-';
					}
				}
				## nvme splits these into two field/value sets
				elsif ($split[$a] eq 'Available Spare'){
					$split[$r] =~ s/%$//;
					$holder{'spare'} = int($split[$r]) if main::is_numeric($split[$r]);
				}
				elsif ($split[$a] eq 'Available Spare Threshold'){
					$split[$r] =~ s/%$//;
					if ($holder{'spare'} && main::is_numeric($split[$r]) && $split[$r]/$holder{'spare'} > 0.92){
						$data->[$i]{'smart-available-reserved-space-ar'} = $holder{'spare'};
						$data->[$i]{'smart-available-reserved-space-t'} = int($split[$r]);
					}
				}
				elsif ($split[$a] eq 'End-to-End_Error'){
					if ($b_attributes && int($split[$r]) > 0 && $split[$t]){
						$data->[$i]{'smart-end-to-end-av'} = $split[$v];
						$data->[$i]{'smart-end-to-end-t'} = $split[$t];
						$data->[$i]{'smart-end-to-end-f'} = $split[$f] if $split[$f] ne '-';
					}
				}
				# seen raw value: 0/8415644
				elsif ($split[$a] eq 'Raw_Read_Error_Rate'){
					if ($b_attributes && $split[$v] && $split[$t] && $split[$t]/$split[$v] > 0.92){
						$data->[$i]{'smart-raw-read-error-rate-av'} = $split[$v];
						$data->[$i]{'smart-raw-read-error-rate-t'} = $split[$t];
						$data->[$i]{'smart-raw-read-error-rate-f'} = $split[$f] if $split[$f] ne '-';
					}
				}
				elsif ($split[$a] eq 'Reallocated_Sector_Ct'){
					if ($b_attributes && int($split[$r]) > 0 && $split[$t]){
						$data->[$i]{'smart-reallocated-sectors-av'} = $split[$v];
						$data->[$i]{'smart-reallocated-sectors-t'} = $split[$t];
						$data->[$i]{'smart-reallocated-sectors-f'} = $split[$f] if $split[$f] ne '-';
					}
				}
				elsif ($split[$a] eq 'Retired_Block_Count'){
					if ($b_attributes && int($split[$r]) > 0 && $split[$t]){
						$data->[$i]{'smart-retired-blocks-av'} = $split[$v];
						$data->[$i]{'smart-retired-blocks-t'} = $split[$t];
						$data->[$i]{'smart-retired-blocks-f'} = $split[$f] if $split[$f] ne '-';
					}
				}
				elsif ($split[$a] eq 'Runtime_Bad_Block'){
					if ($b_attributes && $split[$v] && $split[$t] && $split[$t]/$split[$v] > 0.92){
						$data->[$i]{'smart-runtime-bad-block-av'} = $split[$v];
						$data->[$i]{'smart-runtime-bad-block-t'} = $split[$t];
						$data->[$i]{'smart-runtime-bad-block-f'} = $split[$f] if $split[$f] ne '-';
					}
				}
				elsif ($split[$a] eq 'Seek_Error_Rate'){
					# value 72; threshold either 000 or 30
					if ($b_attributes && $split[$v] && $split[$t] && $split[$t]/$split[$v] > 0.92){
						$data->[$i]{'smart-seek-error-rate-av'} = $split[$v];
						$data->[$i]{'smart-seek-error-rate-t'} = $split[$t];
						$data->[$i]{'smart-seek-error-rate-f'} = $split[$f] if $split[$f] ne '-';
					}
				}
				elsif ($split[$a] eq 'Spin_Up_Time'){
					# raw will always be > 0 on spinning disks
					if ($b_attributes && $split[$v] && $split[$t] && $split[$t]/$split[$v] > 0.92){
						$data->[$i]{'smart-spinup-time-av'} = $split[$v];
						$data->[$i]{'smart-spinup-time-t'} = $split[$t];
						$data->[$i]{'smart-spinup-time-f'} = $split[$f] if $split[$f] ne '-';
					}
				}
				elsif ($split[$a] eq 'SSD_Life_Left'){
					# raw will always be > 0 on spinning disks
					if ($b_attributes && $split[$v] && $split[$t] && $split[$t]/$split[$v] > 0.92){
						$data->[$i]{'smart-ssd-life-left-av'} = $split[$v];
						$data->[$i]{'smart-ssd-life-left-t'} = $split[$t];
						$data->[$i]{'smart-ssd-life-left-f'} = $split[$f] if $split[$f] ne '-';
					}
				}
				elsif ($split[$a] eq 'Unused_Rsvd_Blk_Cnt_Tot'){
					# raw will always be > 0 on spinning disks
					if ($b_attributes && $split[$v] && $split[$t] && $split[$t]/$split[$v] > 0.92){
						$data->[$i]{'smart-unused-reserve-block-av'} = $split[$v];
						$data->[$i]{'smart-unused-reserve-block-t'} = $split[$t];
						$data->[$i]{'smart-unused-reserve-block-f'} = $split[$f] if $split[$f] ne '-';
					}
				}
				elsif ($split[$a] eq 'Used_Rsvd_Blk_Cnt_Tot'){
					# raw will always be > 0 on spinning disks
					if ($b_attributes && $split[$v] && $split[$t] && $split[$t]/$split[$v] > 0.92){
						$data->[$i]{'smart-used-reserve-block-av'} = $split[$v];
						$data->[$i]{'smart-used-reserve-block-t'} = $split[$t];
						$data->[$i]{'smart-used-reserve-block-f'} = $split[$f] if $split[$f] ne '-';
					}
				}
				elsif ($b_attributes){
					if ($split[$y] eq 'Pre-fail' && ($split[$f] ne '-' ||
					 ($split[$t] && $split[$v] && $split[$t]/$split[$v] > 0.92))){
						$num++;
						$data->[$i]{'smart-unknown-' . $num . '-a'} = $split[$a];
						$data->[$i]{'smart-unknown-' . $num . '-v'} = $split[$v];
						$data->[$i]{'smart-unknown-' . $num . '-w'} = $split[$v];
						$data->[$i]{'smart-unknown-' . $num . '-t'} = $split[$t];
						$data->[$i]{'smart-unknown-' . $num . '-f'} = $split[$f] if $split[$f] ne '-';
					}
				}
			}
		}
	}
	print Data::Dumper::Dumper $data if $dbg[19];
	eval $end if $b_log;
}

# check for usb/firewire/[and thunderbolt when data found]
sub peripheral_data {
	eval $start if $b_log;
	my ($id) = @_;
	my ($type) = ('');
	# print "$id here\n";
	if (@by_id){
		foreach (@by_id){
			if ("/dev/$id" eq Cwd::abs_path($_)){
				# print "$id here\n";
				if (/usb-/i){
					$type = 'USB';
				}
				elsif (/ieee1394-/i){
					$type = 'FireWire';
				}
				last;
			}
		}
	}
	# note: sometimes with wwn- numbering usb does not appear in by-id but it does in by-path
	if (!$type && @by_path){
		foreach (@by_path){
			if ("/dev/$id" eq Cwd::abs_path($_)){
				if (/usb-/i){
					$type = 'USB';
				}
				elsif (/ieee1394--/i){
					$type = 'FireWire';
				}
				last;
			}
		}
	}
	eval $end if $b_log;
	return $type;
}

sub disk_data_advanced {
	eval $start if $b_log;
	my ($set_cmd,$id) = @_;
	my ($cmd,$pt,$program,@data);
	my $advanced = [];
	if ($set_cmd ne 'unset'){
		$advanced->[0] = $set_cmd;
	}
	else {
		# runs as user, but is SLOW: udisksctl info -b /dev/sda
		# line: org.freedesktop.UDisks2.PartitionTable:
		# Type:               dos
		if ($program = main::check_program('udevadm')){
			$advanced->[0] = "$program info -q property -n ";
		}
		elsif ($b_root && -e "/lib/udev/udisks-part-id"){
			$advanced->[0] = "/lib/udev/udisks-part-id /dev/";
		}
		elsif ($b_root && ($program = main::check_program('fdisk'))){
			$advanced->[0] = "$program -l /dev/";
		}
		if (!$advanced->[0]){
			$advanced->[0] = 'na'
		}
	}
	if ($advanced->[0] ne 'na'){
		$cmd = "$advanced->[0]$id 2>&1";
		main::log_data('cmd',$cmd) if $b_log;
		@data = main::grabber($cmd);
		# for pre ~ 2.30 fdisk did not show gpt, but did show gpt scheme error, so
		# if no gpt match, it's dos = mbr
		if ($cmd =~ /fdisk/){
			foreach (@data){
				if (/^WARNING:\s+GPT/){
					$advanced->[1] = 'gpt';
					last;
				}
				elsif (/^Disklabel\stype:\s*(.+)/i){
					$advanced->[1] = $1;
					last;
				}
			}
			$advanced->[1] = 'dos' if !$advanced->[1];
		}
		else {
			foreach (@data){
				if (/^(UDISKS_PARTITION_TABLE_SCHEME|ID_PART_TABLE_TYPE)/){
					my @working = split('=', $_);
					$advanced->[1] = $working[1];
				}
				elsif (/^ID_ATA_ROTATION_RATE_RPM/){
					my @working = split('=', $_);
					$advanced->[2] = $working[1];
				}
				last if defined $advanced->[1] && defined $advanced->[2];
			}
		}
		$advanced->[1] = 'mbr' if $advanced->[1] && lc($advanced->[1]) eq 'dos';
	}
	eval $end if $b_log;
	return $advanced;
}

sub scsi_data {
	eval $start if $b_log;
	my ($file) = @_;
	my @temp = main::reader($file);
	my $scsi = [];
	my ($firmware,$model,$vendor) = ('','','');
	foreach (@temp){
		if (/Vendor:\s*(.*)\s+Model:\s*(.*)\s+Rev:\s*(.*)/i){
			$vendor = $1;
			$model = $2;
			$firmware = $3;
		}
		if (/Type:/i){
			if (/Type:\s*Direct-Access/i){
				push(@$scsi, {
				'vendor' => $vendor,
				'model' => $model,
				'firmware' => $firmware,
				});
			}
			else {
				($firmware,$model,$vendor) = ('','','');
			}
		}
	}
	main::log_data('dump','@$scsi', $scsi) if $b_log;
	eval $end if $b_log;
	return $scsi;
}

# @b_id has already been cleaned of partitions, wwn-, nvme-eui
sub disk_data_by_id {
	eval $start if $b_log;
	my ($device) = @_;
	my ($model,$serial,$vendor) = ('','','');
	my $disk_data = [];
	foreach (@by_id){
		if ($device eq Cwd::abs_path($_)){
			my @data = split('_', $_);
			last if scalar @data < 2; # scsi-3600508e000000000876995df43efa500
			$serial = pop @data if @data;
			# usb-PNY_USB_3.0_FD_3715202280-0:0
			$serial =~ s/-[0-9]+:[0-9]+$//;
			$model = join(' ', @data);
			# get rid of the ata-|nvme-|mmc- etc
			$model =~ s/^\/dev\/disk\/by-id\/([^-]+-)?//;
			$model = main::clean_disk($model);
			my $result = disk_vendor($model,$serial);
			$vendor = $result->[0] if $result->[0];
			$model = $result->[1] if $result->[1];
			# print $device, '::', Cwd::abs_path($_),'::', $model, '::', $vendor, '::', $serial, "\n";
			@$disk_data = ($model,$vendor,$serial);
			last;
		}
	}
	eval $end if $b_log;
	return $disk_data;
}

## START DISK VENDOR BLOCK ##
# 0 - match pattern; 1 - replace pattern; 2 - vendor print; 3 - serial pattern
sub set_disk_vendors {
	eval $start if $b_log;
	$vendors = [
	## MOST LIKELY/COMMON MATCHES ##
	['(Crucial|^(C[34]00$|(C300-)?CTF|(FC)?CT|DDAC|M4(\b|SSD))|-CT|Gizmo!)','Crucial','Crucial',''],
	# H10 HBRPEKNX0202A NVMe INTEL 512GB
	['(\bINTEL\b|^(SSD(PAM|SA2)|HBR|(MEM|SSD)PEB?K|SSD(MCE|S[AC])))','\bINTEL\b','Intel',''], 
	['^(Intel[\s_-]?)?SRCSAS?','^Intel','Intel RAID',''], 
	# note: S[AV][1-9]\d can trigger false positives
	['(K(ING)?STON|^(OM8P|RBU|S[AV][1234]00|S[HMN]S|SK[CY]|SQ5|SS200|SVP|SS0|SUV|SNV|T52|T[AB]29|Ultimate CF)|V100|DataTraveler|DT\s?(DUO|Microduo|101)|HyperX|13fe\b)','(KINGSTON|13fe)','Kingston',''], # maybe SHS: SHSS37A SKC SUV
	# must come before samsung MU. NOTE: toshiba can have: TOSHIBA_MK6475GSX: mush: MKNSSDCR120GB_
	['(^MKN|Mushkin)','Mushkin','Mushkin',''], # MKNS
	# MU = Multiple_Flash_Reader too risky: |M[UZ][^L] HD103SI HD start risky
	# HM320II HM320II HM
	['(SAMSUNG|^(AWMB|[BC]DS20|[BC]WB|BJ[NT]|[BC]GND|CJ[NT]|CKT|CUT|[DG]3 Station|DUO\b|DUT|EB\dMW|E[CS]\d[A-Z]\d|FD\d[A-Z]\dGE4S5|[GS]2 Portable|GN|HD\d{3}[A-Z]{2}$|(HM|SP)\d{2}|HS\d|M[AB]G\d[FG]|MCC|MCBOE|MCG\d+GC|[CD]JN|MZ|^G[CD][1-9][QS]|P[BM]\d|(SSD\s?)?SM\s?841)|^SSD\s?[89]\d{2}\s(DCT|PRO|QVD|\d+[GT]B)|\bEVO\b|SV\d|[BE][A-Z][1-9]QT|YP\b|[CH]N-M|MMC[QR]E)','SAMSUNG','Samsung',''], # maybe ^SM, ^HM
	# Android UMS Composite?U1
	['(SanDisk|0781|^(A[BCD]LC[DE]|AFGCE|D[AB]4|DX[1-9]|Extreme|Firebird|S[CD]\d{2}G|SC\d{3,4}|SD(CF|S[S]?[ADQ]|SL\d+G|SU\d|U\d|\sUltra)|SDW[1-9]|SE\d{2}|SEM\d{2}|\d[STU]|U(3\b|1\d0))|Clip Sport|Cruzer|iXpand|SN(\d+G|128|256)|SSD (Plus|U1[01]0) [1-9]|ULTRA\s(FIT|trek|II)|^X[1-6]\d{2})','(SanDisk|0781)','SanDisk',''],
	# these are HP/Sandisk cobranded. DX110064A5xnNMRI ids as HP and Sandisc
	['(^DX[1-9])','^(HP\b|SANDDISK)','Sandisk/HP',''], # ssd drive, must come before seagate ST test
	# real, SSEAGATE Backup+; XP1600HE30002 | 024 HN (spinpoint) ; possible usb: 24AS
	# ST[numbers] excludes other ST starting devices
	['([S]?SEAGATE|^((Barra|Fire)Cuda|BUP|EM\d{3}|Expansion|(ATA\s|HDD\s)?ST\d{2}|5AS|X[AFP])|Backup(\+|\s?Plus)\s?(Hub)?|DS2\d|Expansion Desk|FreeAgent|GoFlex|INIC|IronWolf|OneTouch|Slim\s?BK)','[S]?SEAGATE','Seagate',''], 
	['^(WD|WL[0]9]|Western Digital|My (Book|Passport)|\d*LPCX|Elements|easystore|EA[A-Z]S|EARX|EFRX|EZRX|\d*EAVS|G[\s-]Drive|i HTS|0JD|JP[CV]|MD0|M000|\d+(BEV|(00)?AAK|AAV|AZL|EA[CD]S)|PC\sSN|SN530|SPZX|3200[AB]|2500[BJ]|20G2|5000[AB]|6400[AB]|7500[AB]|00[ABL][A-Z]{2}|SSC\b)','(^WDC|Western\s?Digital)','Western Digital',''],
	# rare cases WDC is in middle of string
	['(\bWDC\b|1002FAEX)','','Western Digital',''],
	
	## THEN BETTER KNOWN ONES ##
	['^(AccelStor|GS\d{3,})','^AccelStor','AccelStor',''],
	['^Acer','^Acer','Acer',''],
	# A-Data can be in middle of string
	['^(.*\bA-?DATA|ASP\d|AX[MN]|CH11|FX63|HV[1-9]|IM2|HD[1-9]|HDD\s?CH|IUM|SX\d|Swordfish)','A-?DATA','A-Data',''],
	['^(ASUS|ROG)','^ASUS','ASUS',''], # ROG ESD-S1C
	# ATCS05 can be hitachi travelstar but not sure
	['^ATP','^ATP\b','ATP',''],
	['^(BlueRay|SSD\d+GM)','^BlueRay','BlueRay',''], 
	# Force MP500
	['^(Corsair|Force\s|(Flash\s*)?(Survivor|Voyager)|Neutron|Padlock)','^Corsair','Corsair',''],
	['^(FUJITSU|MJA|MH[RTVWYZ]\d|MP|MAP\d|F\d00s?-)','^FUJITSU','Fujitsu',''],
	# MAB3045SP shows as HP or Fujitsu, probably HP branded fujitsu
	['^(MAB\d)','^(HP\b|FUJITSU)','Fujitsu/HP',''],
	# note: 2012:  wdc bought hgst
	['^(DKR|HGST|Touro|54[15]0|7250|HC[CT]\d)','^HGST','HGST (Hitachi)',''], # HGST HUA
	['^((ATA\s)?Hitachi|HCS|HD[PST]|DK\d|IC|(HDD\s)?HT|HU|HMS|HDE|0G\d|IHAT)','Hitachi','Hitachi',''], 
	# vb: VB0250EAVER but clashes with vbox; HP_SSD_S700_120G ;GB0500EAFYL GB starter too generic?
	['^(HP\b|c350|DF\d|EG0\d{3}|EX9\d\d|G[BJ]\d|F[BK]|0-9]|HC[CPY]\d|MM\d{4}|[MV]B[0-6]|PSS|VO0|VK0|v\d{3}[bgorw]$|x\d{3}[w]$|XR\d{4})','^HP','HP',''], 
	['^(Lexar|LSD|JumpDrive|JD\s?Firefly|LX\d|WorkFlow)','^Lexar','Lexar',''], # mmc-LEXAR_0xb016546c; JD Firefly;
	# these must come before maxtor because STM
	['^STmagic','^STmagic','STmagic',''],
	['^(STMicro|SMI|CBA)','^(STMicroelectronics|SMI)','SMI (STMicroelectronics)',''],
	# note M2 M3 is usually maxtor, but can be samsung. Can conflict with Team: TM\d{4}|
	['^(MAXTOR|Atlas|4R\d{2}|E0\d0L|L(250|500)|[KL]0[1-9]|Y\d{3}[A-Z]|STM\d|F\d{3}L)','^MAXTOR','Maxtor',''], 
	# OCZSSD2-2VTXE120G is OCZ-VERTEX2_3.5
	['^(OCZ|Agility|APOC|D2|DEN|DEN|DRSAK|EC188|FTNC|GFGC|MANG|MMOC|NIMC|NIMR|PSIR|RALLY2|TALOS2|TMSC|TRSAK|VERTEX|Trion|Onyx|Vector[\s-]?15)','^OCZ[\s-]','OCZ',''],
	['^(OWC|Aura|Mercury[\s-]?(Electra|Extreme))','^OWC\b','OWC',''],
	['^(Philips|GoGear)','^Philips','Philips',''],
	['^PIONEER','^PIONEER','Pioneer',''],
	['^(PNY|Hook\s?Attache|SSD2SC|(SSD7?)?EP7|CS\d{3}|Elite\s?P)','^PNY\s','PNY','','^PNY'],
	# note: get rid of: M[DGK] becasue mushkin starts with MK
	# note: seen: KXG50ZNV512G NVMe TOSHIBA 512GB | THNSN51T02DUK NVMe TOSHIBA 1024GB 
	['(TOSHIBA|TransMemory|KBG4|^((A\s)?DT01A|M[GKQ]\d|HDW|SA\d{2}G$|(008|016|032|064|128)G[379E][0-9A]$|[S]?TOS|THN)|0930|KSG\d)','S?(TOSHIBA|0930)','Toshiba',''], # scsi-STOSHIBA_STOR.E_EDITION_
	
	## LAST: THEY ARE SHORT AND COULD LEAD TO FALSE ID, OR ARE UNLIKELY ##
	# unknown: AL25744_12345678; ADP may be usb 2.5" adapter; udisk unknown: Z1E6FTKJ 00AAKS
	# SSD2SC240G726A10 MRS020A128GTS25C EHSAJM0016GB
	['^2[\s-]?Power','^2[\s-]?Power','2-Power',''], 
	['^(3ware|9650SE)','^3ware','3ware (controller)',''], 
	['^5ACE','^5ACE','5ACE',''], # could be seagate: ST316021 5ACE
	['^(Aar(vex)?|AX\d{2})','^AARVEX','AARVEX',''],
	['^(AbonMax|ASU\d)','^AbonMax','AbonMax',''],
	['^Acasis','^Acasis','Acasis (hub)',''],
	['^Acclamator','^Acclamator','Acclamator',''],
	['^(Actions|HS USB Flash|10d6)','^(Actions|10d6)','Actions',''],
	['^(A-?DATA|ED\d{3}|NH01|Swordfish|SU\d{3}|SX\d{3}|XM\d{2})','^A-?DATA','ADATA',''],
	['^Addlink','^Addlink','Addlink',''],
	['^(ADplus|SuperVer\b)','^ADplus','ADplus',''],
	['^ADTRON','^ADTRON','Adtron',''],
	['^(Advantech|SQF)','^Advantech','Advantech',''],
	['^AEGO','^AEGO','AEGO',''],
	['^AFOX','^AFOX','AFOX',''],
	['^AFTERSHOCK','^AFTERSHOCK','AFTERSHOCK',''],
	['^(Agile|AGI)','^(AGI|Agile\s?Gear\s?Int[a-z]*)','AGI',''],
	['^Aigo','^Aigo','Aigo',''],
	['^AirDisk','^AirDisk','AirDisk',''],
	['^Aireye','^Aireye','Aireye',''],
	['^Alcatel','^Alcatel','Alcatel',''],
	['^(Alcor(\s?Micro)?|058F)','^(Alcor(\s?Micro)?|058F)','Alcor Micro',''],
	['^Alfawise','^Alfawise','Alfawise',''],
	['(^ALKETRON|FireWizard)','^ALKETRON','ALKETRON',''],
	['^ANACOMDA','^ANACOMDA','ANACOMDA',''],
	['^Android','^Android','Android',''],
	['^ANK','^Anker','Anker',''],
	['^Ant[\s_-]?Esports','^Ant[\s_-]?Esports','Ant Esports',''],
	['^Anucell','^Anucell','Anucell',''],
	['^Apotop','^Apotop','Apotop',''],
	# must come before AP|Apacer
	['^(APPLE|iPod|SSD\sSM\d+[CEGT])','^APPLE','Apple',''],
	['^(AP|Apacer)','^Apacer','Apacer',''],
	['^(Apricom|SATAWire)','^Apricom','Apricom',''],
	['^(A-?RAM|ARSSD)','^A-?RAM','A-RAM',''],
	['^Arch','^Arch(\s*Memory)?','Arch Memory',''],
	['^(Asenno|AS[1-9])','^Asenno','Asenno',''],
	['^Asgard','^Asgard','Asgard',''],
	['^ASint','^ASint','ASint',''],
	['^(ASL|\d+[A-Z]{1,2}\d+-ASL\b)','^ASL','ASL',''], # 99IB3321-ASL
	['^(ASM|2115)','^ASM','ASMedia',''],#asm1153e
	['^ASolid','^ASolid','ASolid',''],
	# ASTC (Advanced Storage Technology Consortium)
	['^(AVEXIR|AVSSD)','^AVEXIR','Avexir',''],
	['^Axiom','^Axiom','Axiom',''],
	['^(Baititon|BT\d)','^Baititon','Baititon',''],
	['^Bamba','^Bamba','Bamba',''],
	['^(Beckhoff)','^Beckhoff','Beckhoff',''],
	['^Bell\b','^Bell','Packard Bell',''],
	['^(BelovedkaiAE|GhostPen)','^BelovedkaiAE','BelovedkaiAE',''],
	['^BHM\b','^BHM','BHM',''],
	['^(BHT|WR20)','^BHT','BHT',''],
	['^(Big\s?Reservoir|B[RG][_\s-])','^Big\s?Reservoir','Big Reservoir',''],
	['^BIOSTAR','^BIOSTAR','Biostar',''],
	['^BIWIN','^BIWIN','BIWIN',''],
	['^Blackpcs','^Blackpcs','Blackpcs',''],
	['^(BlitzWolf|BW-?PSSD)','^BlitzWolf','BlitzWolf',''],
	['^(BlueRay|SDM\d)','^BlueRay','BlueRay',''],
	['^Bory','^Bory','Bory',''],
	['^Braveeagle','^Braveeagle','BraveEagle',''],
	['^(BUFFALO|BSC)','^BUFFALO','Buffalo',''], # usb: BSCR05TU2
	['^Bugatek','^Bugatek','Bugatek',''],
	['^Bulldozer','^Bulldozer','Bulldozer',''],
	['^BUSlink','^BUSlink','BUSlink',''],
	['^(Canon|MP49)','^Canon','Canon',''],
	['^Centerm','^Centerm','Centerm',''],
	['^(Centon|DS pro)','^Centon','Centon',''],
	['^(CFD|CSSD)','^CFD','CFD',''],
	['^CHIPAL','^CHIPAL','CHIPAL',''],
	['^(Chipsbank|CHIPSBNK)','^Chipsbank','Chipsbank',''],
	['^(Chipfancie)','^Chipfancier','Chipfancier',''],
	['^Clover','^Clover','Clover',''],
	['^CODi','^CODi','CODi',''],
	['^Colorful\b','^Colorful','Colorful',''],
	['^CONSISTENT','^CONSISTENT','Consistent',''],
	# note: www.cornbuy.com is both a brand and also sells other brands, like newegg
	# addlink; colorful; goldenfir; kodkak; maxson; netac; teclast; vaseky
	['^Corn','^Corn','Corn',''],
	['^CnMemory|Spaceloop','^CnMemory','CnMemory',''],
	['^(Creative|(Nomad\s?)?MuVo)','^Creative','Creative',''],
	['^CSD','^CSD','CSD',''],
	['^CYX\b','^CYX','CYX',''],
	['^(Dane-?Elec|Z Mate)','^Dane-?Elec','DaneElec',''],
	['^DATABAR','^DATABAR','DataBar',''],
	# Daplink vfs is an ARM software thing
	['^(Data\s?Memory\s?Systems|DMS)','^Data\s?Memory\s?Systems','Data Memory Systems',''],
	['^Dataram','^Dataram','Dataram',''],
	['^DELAIHE','^DELAIHE','DELAIHE',''],
	# DataStation can be Trekstore or I/O gear
	['^Dell\b','^Dell','Dell',''],
	['^DeLOCK','^Delock(\s?products)?','Delock',''],
	['^Derler','^Derler','Derler',''],
	['^detech','^detech','DETech',''],
	['^DEXP','^DEXP','DEXP',''],
	['^DGM','^DGM\b','DGM',''],
	['^(DICOM|MAESTRO)','^DICOM','DICOM',''],
	['^Digifast','^Digifast','Digifast',''],
	['^DIGITAL\s?FILM','DIGITAL\s?FILM','Digital Film',''],
	['^(Digma|Run(\sY2)?\b)','^Digma','Digma',''],
	['^Dikom','^Dikom','Dikom',''],
	['^DINGGE','^DINGGE','DINGGE',''],
	['^Disain','^Disain','Disain',''],
	['^(Disco|Go-Infinity)','^Disco','Disco',''],
	['^(Disk2go|Three[\s_-]?O)','^Disk2go','Disk2go',''],
	['^(Disney|PIX[\s]?JR)','^Disney','Disney',''],
	['^(Doggo|DQ-|Sendisk|Shenchu)','^(doggo|Sendisk(.?Shenchu)?|Shenchu(.?Sendisk)?)','Doggo (SENDISK/Shenchu)',''],
	['^(Dogfish|M\.2 2242|Shark)','^Dogfish(\s*Technology)?','Dogfish Technology',''],
	['^DragonDiamond','^DragonDiamond','DragonDiamond',''],
	['^(DREVO\b|X1\s\d+[GT])','^DREVO','Drevo',''],
	['^DSS','^DSS DAHUA','DSS DAHUA',''],
	['^(Duex|DX\b)','^Duex','Duex',''], # DX\d may be starter for sandisk string
	['^(Dynabook|AE[1-3]00)','^Dynabook','Dynabook',''],
	# DX1100 is probably sandisk, but could be HP, or it could be hp branded sandisk
	['^(Eaget|V8$)','^Eaget','Eaget',''],
	['^(Easy[\s-]?Memory)','^Easy[\s-]?Memory','Easy Memory',''],
	['^EDGE','^EDGE','EDGE Tech',''],
	['^(EDILOCA|ES\d+\b)','^EDILOCA','Ediloca',''],
	['^Elecom','^Elecom','Elecom',''],
	['^Eluktro','^Eluktronics','Eluktronics',''],
	['^Emperor','^Emperor','Emperor',''],
	['^Emtec','^Emtec','Emtec',''],
	['^ENE\b','^ENE','ENE',''],
	['^Energy','^Energy','Energy',''],
	['^eNova','^eNOVA','eNOVA',''],
	['^Epson','^Epson','Epson',''],
	['^(Etelcom|SSD051)','^Etelcom','Etelcom',''],
	['^(Shenzhen\s)?Etopso(\sTechnology)?','^(Shenzhen\s)?Etopso(\sTechnology)?','Etopso',''],
	['^EURS','^EURS','EURS',''],
	['^eVAULT','^eVAULT','eVAULT',''],
	['^EVM','^EVM','EVM',''],
	['^eVtran','^eVtran','eVtran',''],
	# NOTE: ESA3... may be IBM PCIe SAD card/drives
	['^(EXCELSTOR|r technology)','^EXCELSTOR( TECHNO(LOGY)?)?','ExcelStor',''],
	['^EXRAM','^EXRAM','EXRAM',''],
	['^EYOTA','^EYOTA','EYOTA',''],
	['^EZCOOL','^EZCOOL','EZCOOL',''],
	['^EZLINK','^EZLINK','EZLINK',''],
	['^Fantom','^Fantom( Drive[s]?)?','Fantom Drives',''],
	['^Fanxiang','^Fanxiang','Fanxiang',''],
	['^(Faspeed|K3[\s-])','^Faspeed','Faspeed',''],
	['^FASTDISK','^FASTDISK','FASTDISK',''],
	['^Festtive','^Festtive','Festtive',''],
	['^FiiO','^FiiO','FiiO',''],
	['^FixMeStick','^FixMeStick','FixMeStick',''],
	['^(FIKWOT|FS\d{3})','^FIKWOT','Kikwot',''],
	['^Fordisk','^Fordisk','Fordisk',''],
	# FK0032CAAZP/FB160C4081 FK or FV can be HP but can be other things
	['^(FORESEE|B[123]0)|P900F|S900M','^FORESEE','Foresee',''],
	['^Founder','^Founder','Founder',''],
	['^(FOXLINE|FLD)','^FOXLINE','Foxline',''], # russian vendor?
	['^(Gateway|W800S)','^Gateway','Gateway',''],
	['^Freecom','^Freecom(\sFreecom)?','Freecom',''],
	['^(FronTech)','^FronTech','Frontech',''],
	['^(Fuhler|FL-D\d{3})','^Fuhler','Fuhler',''],
	['^Gaiver','^Gaiver','Gaiver',''],
	['^(GALAX\b|Gamer\s?L|TA\dD|Gamer[\s-]?V)','^GALAX','GALAX',''],
	['^Galaxy\b','^Galaxy','Galaxy',''],
	['^Gamer[_\s-]?Black','^Gamer[_\s-]?Black','Gamer Black',''],
	['^(Garmin|Fenix|Nuvi|Zumo)','^Garmin','Garmin',''],
	['^Geil','^Geil','Geil',''],
	['^GelL','^GelL','GelL',''], # typo for Geil? GelL ZENITH R3 120GB
	['^(Generic|A3A|G1J3|M0S00|SCA\d{2}|SCY|SLD|S0J\d|UY[567])','^Generic','Generic',''],
	['^(Genesis(\s?Logic)?|05e3)','(Genesis(\s?Logic)?|05e3)','Genesis Logic',''],
	['^Geonix','^Geonix','Geonix',''],
	['^Getrich','^Getrich','Getrich',''],
	['^(Gigabyte|GP-G)','^Gigabyte','Gigabyte',''], # SSD
	['^Gigastone','^Gigastone','Gigastone',''],
	['^Gigaware','^Gigaware','Gigaware',''],
	['^GJN','^GJN\b','GJN',''],
	['^(Gloway|FER\d)','^Gloway','Gloway',''],
	['^GLOWY','^GLOWY','Glowy',''],
	['^Goldendisk','^Goldendisk','Goldendisk',''],
	['^Goldenfir','^Goldenfir','Goldenfir',''],
	['^(Goldkey|GKH\d)','^Goldkey','Goldkey',''],
	['^Golden[\s_-]?Memory','^Golden[\s_-]?Memory','Golden Memory',''],
	['^(Goldkey|GKP)','^Goldkey','GoldKey',''],
	['^(Goline)','^Goline','Goline',''],
	# Wilk Elektronik SA, poland
	['^((Wilk|WE)\s*)?(GOODRAM|GOODDRIVE|IR[\s-]?SSD|IRP|SSDPR|Iridium)','^GOODRAM','GOODRAM',''],
	['^(GreatWall|GW\d{3})','^GreatWall','GreatWall',''],
	['^(GreenHouse|GH\b)','^GreenHouse','GreenHouse',''],
	['^Gritronix','^Gritronixx?','Gritronix',''],
	# supertalent also has FM: |FM
	['^(G[\.]?SKILL)','^G[\.]?SKILL','G.SKILL',''],
	['^G[\s-]*Tech','^G[\s-]*Tech(nology)?','G-Technology',''],
	['^(Gudga|GIM\d+|G[NV](R\d|\d{2,4}\b))','^Gudga','Gudga',''],
	['^(Hajaan|HS[1-9])','^Haajan','Haajan',''],
	['^Haizhide','^Haizhide','Haizhide',''],
	['^(Hama|FlashPen\s?Fancy)','^Hama','Hama',''],
	['^(Hanye|Q60)','^Hanye','Hanye',''],
	['^HDC','^HDC\b','HDC',''],
	['^Hectron','^Hectron','Hectron',''],
	['^HEMA','^HEMA','HEMA',''],
	['(HEORIADY|^HX-0)','^HEORIADY','HEORIADY',''],
	['^(Hikvision|HKVSN|HS-SSD)','^Hikvision','Hikvision',''],
	['^Hi[\s-]?Level ','^Hi[\s-]?Level ','Hi-Level',''], # ^HI\b with no Level?
	['^(Hisense|H8G)','^Hisense','Hisense',''],
	['^Hoodisk','^Hoodisk','Hoodisk',''],
	['^(HUAWEI|HWE)','^HUAWEI','Huawei',''],
	['^Hypertec','^Hypertec','Hypertec',''],
	['^HyperX','^HyperX','HyperX',''],
	['^(HYSSD|HY-)','^HYSSD','HYSSD',''],
	['^(Hyundai|C2S\d|Sapphire)','^Hyundai','Hyundai',''],
	['^iMRAM','^iMRAM','iMRA',''], 
	['^(IBM|DT|ESA[1-9]|ServeRaid)','^IBM','IBM',''], # M5110 too common
	['^IEI Tech','^IEI Tech(\.|nology)?( Corp(\.|oration)?)?','IEI Technology',''],
	['^(IGEL|UD Pocket)','^IGEL','IGEL',''],
	['^(Imation|Nano\s?Pro|HQT)','^Imation(\sImation)?','Imation',''], # Imation_ImationFlashDrive; TF20 is imation/tdk
	['^(IMC|Kanguru)','^IMC\b','IMC',''],
	['^(Inateck|FE20)','^Inateck','Inateck',''],
	['^(Inca\b|Npenterprise)','^Inca','Inca',''],
	['^(Indilinx|IND-)','^Indilinx','Indilinx',''],
	['^INDMEM','^INDMEM','INDMEM',''],
	['^(Infokit)','^Infokit','Infokit',''],
	# note: Initio default controller, means master/slave jumper is off/wrong, not a vendor
	['^Inland','^Inland','Inland',''],
	['^(InnoDisk|DEM\d|Innolite|SATA\s?Slim|DRPS)','^InnoDisk( Corp.)?','InnoDisk',''],
	['(Innostor|1f75)','(Innostor|1f75)','Innostor',''],
	['(^Innovation|Innovation\s?IT)','Innovation(\s*IT)?','Innovation IT',''],
	['^Innovera','^Innovera','Innovera',''],
	['^(I\.?norys|INO-?IH])','^I\.?norys','I.norys','']
	,['(^Insignia|NS[\s-]?PCNV)','^Insignia','Insignia',''],
	['^Intaiel','^Intaiel','Intaiel',''],
	['^(INM|Integral|V\s?Series)','^Integral(\s?Memory)?','Integral Memory',''],
	['^(lntenso|Intenso|(Alu|Basic|Business|Micro|c?Mobile|Premium|Rainbow|Slim|Speed|Twister|Ultra) Line|Rainbow)','^Intenso','Intenso',''],
	['^(I-?O Data|HDCL)','^I-?O Data','I-O Data',''], 
	['^(INO-|i\.?norys)','^i\.?norys','i.norys',''], 
	['^(Integrated[\s-]?Technology|IT\d+)','^Integrated[\s-]?Technology','Integrated Technology',''], 
	['^(Iomega|ZIP\b|Clik!)','^Iomega','Iomega',''], 
	['^(i[\s_-]?portable\b|ATCS)','^i[\s_-]?portable','i-Portable',''],
	['^ISOCOM','^ISOCOM','ISOCOM (Shenzhen Longsys Electronics)',''],
	['^iTE[\s-]*Tech','^iTE[\s-]*Tech(nology)?','iTE Tech',''],
	['^(James[\s-]?Donkey|JD\d)','^James[\s-]?Donkey','James Donkey',''], 
	['^(Jaster|JS\d)','^Jaster','Jaster',''], 
	['^JingX','^JingX','JingX',''], #JingX 120G SSD - not confirmed, but guessing
	['^Jingyi','^Jingyi','Jingyi',''],
	# NOTE: ITY2 120GB hard to find
	['^JMicron','^JMicron(\s?Tech(nology)?)?','JMicron Tech',''], #JMicron H/W raid
	['^JSYERA','^JSYERA','Jsyera',''],
	['^(Jual|RX7)','^Jual','Jual',''], 
	['^(J\.?ZAO|JZ)','^J\.?ZAO','J.ZAO',''], 
	['^Kazuk','^Kazuk','Kazuk',''],
	['(\bKDI\b|^OM3P)','\bKDI\b','KDI',''],
	['^KEEPDATA','^KEEPDATA','KeepData',''],
	['^KLLISRE','^KLLISRE','KLLISRE',''],
	['^KimMIDI','^KimMIDI','KimMIDI',''],
	['^Kimtigo','^Kimtigo','Kimtigo',''],
	['^Kingbank','^Kingbank','Kingbank',''],
	['^(KingCell|KC\b)','^KingCell','KingCell',''],
	['^Kingchux[\s-]?ing','^Kingchux[\s-]?ing','Kingchuxing',''],
	['^(KINGCOMP|KCSSD)','^KINGCOMP','KingComp',''],
	['(KingDian|^NGF|S(280|400))','KingDian','KingDian',''],
	['^(Kingfast|TYFS)','^Kingfast','Kingfast',''],
	['^KingMAX','^KingMAX','KingMAX',''],
	['^Kingrich','^Kingrich','Kingrich',''],
	['^Kingsand','^Kingsand','Kingsand',''],
	['KING\s?SHA\s?RE','KING\s?SHA\s?RE','KingShare',''],
	['^(KingSpec|ACSC|C3000|KS[DQ]|MSH|N[ET]-\d|NX-\d{2,4}|P3$|P4\b|PA[_-]?(18|25)|Q-180|SPK|T-(3260|64|128)|Z(\d\s|F\d))','^KingSpec','KingSpec',''],
	['^KingSSD','^KingSSD','KingSSD',''],
	# kingwin docking, not actual drive
	['^(EZD|EZ-Dock)','','Kingwin Docking Station',''],
	['^Kingwin','^Kingwin','Kingwin',''],
	['^KLLISRE','^KLLISRE','KLLISRE',''],
	['(KIOXIA|^K[BX]G\d)','KIOXIA','KIOXIA',''], # company name comes after product ID
	['^(KLEVV|NEO\sN|CRAS)','^KLEVV','KLEVV',''],
	['^(Kodak|Memory\s?Saver)','^Kodak','Kodak',''],
	['^(KOOTION)','^KOOTION','KOOTION',''],
	['^(KUAIKAI|MSAM)','^KUAIKAI','KuaKai',''],
	['(KUIJIA|DAHUA)','^KUIJIA','KUIJIA',''],
	['^KUNUP','^KUNUP','KUNUP',''],
	['^KUU','^KUU\b','KUU',''], # KUU-128GB
	['^(Lacie|P92|itsaKey|iamaKey)','^Lacie','LaCie',''],
	['^LANBO','^LANBO','LANBO',''],
	['^LankXin','^LankXin','LankXin',''],
	['^LANTIC','^LANTIC','Lantic',''],
	['^Lapcare','^Lapcare','Lapcare',''],
	['^(Lazos|L-?ISS)','^Lazos','Lazos',''],
	['^LDLC','^LDLC','LDLC',''],
	# LENSE30512GMSP34MEAT3TA / UMIS RPITJ256PED2MWX
	['^(LEN|UMIS|Think)','^Lenovo','Lenovo',''],
	['^RPFT','','Lenovo O.E.M.',''],
	# JAJS300M120C JAJM600M256C JAJS600M1024C JAJS600M256C JAJMS600M128G 
	['^(Leven|JAJ[MS])','^Leven','Leven',''],
	['^(LEQIXIANG)','^LEQIXIANG','Leqixiang',''],
	['^(LG\b|Xtick)','^LG','LG',''],
	['^Lidermix','Lidermix','Lidermix',''],
	['(LITE[-\s]?ON[\s-]?IT)','LITE[-]?ON[\s-]?IT','LITE-ON IT',''], # LITEONIT_LSS-24L6G
	# PH6-CE240-L; CL1-3D256-Q11 NVMe LITEON 256GB
	['(LITE[-\s]?ON|^PH[1-9]|^DMT|^CV\d-|L(8[HT]|AT|C[HST]|JH|M[HST]|S[ST])-|^S900)','LITE[-]?ON','LITE-ON',''], 
	['^LONDISK','^LONDISK','LONDISK',''],
	['^Longline','^Longline','Longline',''],
	['^LuminouTek','^LuminouTek','LuminouTek',''],
	['^Lunatic','^Lunatic','Lunatic',''],
	['^(LSI|MegaRAID|MR\d{3,4}\b)','^LSI\b','LSI',''],
	['^(M-Systems|DiskOnKey)','^M-Systems','M-Systems',''],
	['^(Mach\s*Xtreme|MXSSD|MXU|MX[\s-])','^Mach\s*Xtreme','Mach Xtreme',''],
	['^(MacroVIP|MV(\d|GLD))','^MacroVIP','MacroVIP',''], # maybe MV alone
	['^Mainic','^Mainic','Mainic',''],
	['^(MARSHAL\b|MAL\d)','^MARSHAL','Marshal',''],
	['^Maxell','^Maxell','Maxell',''],
	['^Maximus','^Maximus','Maximus',''],
	['^MAXIO','^MAXIO','Maxio',''],
	['^Maxmem','^Maxmem','Maxmem',''],
	['^Maxone','^Maxone','Maxone',''],
	['^MARVELL','^MARVELL','Marvell',''],
	['^Maxsun','^Maxsun','Maxsun',''],
	['^MDT\b','^MDT','MDT (rebuilt WD/Seagate)',''], # mdt rebuilds wd/seagate hdd
	# MD1TBLSSHD, careful with this MD starter!!
	['^MD[1-9]','^Max\s*Digital','MaxDigital',''],
	['^Medion','^Medion','Medion',''],
	['^(MEDIAMAX|WL\d{2})','^MEDIAMAX','MediaMax',''],
	['^(Memorex|TravelDrive|TD\s?Classic)','^Memorex','Memorex',''],
	['^Mengmi','^Mengmi','Mengmi',''],
	['^MicroFrom','^MicroFrom','MicroFrom',''],
	['^MGTEC','^MGTEC','MGTEC',''],
	# must come before micron
	['^(Mtron|MSP)','^Mtron','Mtron',''],
	# note: C300/400 can be either micron or crucial, but C400 is M4 from crucial
	['(^(Micron|2200[SV]|MT|M5|(\d+|[CM]\d+)\sMTF)|00-MT)','^Micron','Micron',''],# C400-MTFDDAK128MAM
	['^(Microsoft|S31)','^Microsoft','Microsoft',''],
	['^MidasForce','^MidasForce','MidasForce',''],
	['^Milan','^Milan','Milan',''],
	['^(Mimoco|Mimobot)','^Mimoco','Mimoco',''],
	['^MINIX','^MINIX','MINIX',''],
	['^Miracle','^Miracle','Miracle',''],
	['^MLLSE','^MLLSE','MLLSE',''],
	['^Moba','^Moba','Moba',''],
	# Monster MONSTER DIGITAL
	['^(Monster\s)+(Digital)?|OD[\s-]?ADVANCE','^(Monster\s)+(Digital)?','Monster Digital',''],
	['^Morebeck','^Morebeck','Morebeck',''],
	['^(Moser\s?Bear|MBIL)','^Moser\s?Bear','Moser Bear',''],
	['^(Motile|SSM\d)','^Motile','Motile',''],
	['^(Motorola|XT\d{4}|Moto[\s-]?[EG])','^Motorola','Motorola',''],
	['^Moweek','^Moweek','Moweek',''],
	['^(Move[\s-]?Speed|YSSD)','^Move[\s-]?Speed','Move Speed',''],
	#MRMAD4B128GC9M2C
	['^(MRMA|Memoright)','^Memoright','Memoright',''],
	['^MSI\b','^MSI\b','MSI',''],
	['^MTASE','^MTASE','MTASE',''],
	['^MTRON','^MTRON','MTRON',''],
	['^(MyDigitalSSD|BP[4X])','^MyDigitalSSD','MyDigitalSSD',''], # BP4 = BulletProof4
	['^MyMedia','^MyMedia','MyMedia',''],
	['^(Myson)','^Myson([\s-]?Century)?([\s-]?Inc\.?)?','Myson Century',''],
	['^(Natusun|i-flashdisk)','^Natusun','Natusun',''],
	['^(Neo\s*Forza|NFS\d)','^Neo\s*Forza','Neo Forza',''],
	['^(Netac|NS\d{3}|OnlyDisk|S535N)','^Netac','Netac',''],
	['^Newsmy','^Newsmy','Newsmy',''],
	['^NFHK','^NFHK','NFHK',''],
	# NGFF is a type, like msata, sata
	['^Nik','^Nikimi','Nikimi',''],
	['^NOREL','^NOREL(SYS)?','NorelSys',''],
	['^(N[\s-]?Tech|NT\d)','^N[\s-]?Tec','N Tech',''], # coudl be ^NT alone
	['^NXTech','^NXTech','NXTech',''],
	['^ODYS','^ODYS','ODYS',''],
	['^Olympus','^Olympus','Olympus',''],
	['^Orico','^Orico','Orico',''],
	['^Ortial','^Ortial','Ortial',''],
	['^OSC','^OSC\b','OSC',''],
	['^(Ovation)','^Ovation','Ovation',''],
	['^oyunkey','^oyunkey','Oyunkey',''],
	['^PALIT','PALIT','Palit',''], # ssd 
	['^Panram','^Panram','Panram',''], # ssd 
	['^(Parker|TP00)','^Parker','Parker',''],
	['^(Pasoul|OASD)','^Pasoul','Pasoul',''],
	['^(Patriot|PS[8F]|P2\d{2}|PBT|VPN|Viper|Burst|Blast|Blaze|Pyro|Ignite)','^Patriot([-\s]?Memory)?','Patriot',''],#Viper M.2 VPN100
	['^PERC\b','','Dell PowerEdge RAID Card',''], # ssd 
	['(PHISON[\s-]?|ESR\d|PSE)','PHISON[\s-]?','Phison',''],# E12-256G-PHISON-SSD-B3-BB1
	['^(Pichau[\s-]?Gaming|PG\d{2})','^Pichau[\s-]?Gaming','Pichau Gaming',''],
	['^Pioneer','Pioneer','Pioneer',''],
	['^Platinet','Platinet','Platinet',''],
	['^(PLEXTOR|PX-)','^PLEXTOR','Plextor',''],
	['^(Polion)','^Polion','Polion',''],
	['^(PQI|Intelligent\s?Stick|Cool\s?Drive)','^PQI','PQI',''],
	['^(Premiertek|QSSD|Quaroni)','^Premiertek','Premiertek',''],
	['^(-?Pretec|UltimateGuard)','-?Pretec','Pretec',''],
	['^(Prolific)','^Prolific( Technolgy Inc\.)?','Prolific',''],
	# PS3109S9 is the result of an error condition with ssd controller: Phison PS3109
	['^PUSKILL','^PUSKILL','Puskill',''],
	['QEMU','^\d*QEMU( QEMU)?','QEMU',''], # 0QUEMU QEMU HARDDISK
	['(^Quantum|Fireball)','^Quantum','Quantum',''],
	['(^QOOTEC|QMT)','^QOOTEC','QOOTEC',''],
	['^(QUMO|Q\dDT)','^QUMO','Qumo',''],
	['^QOPP','^QOPP','Qopp',''],
	['^Qunion','^Qunion','Qunion',''],
	['^(R[3-9]|AMD\s?(RADEON)?|Radeon)','AMD\s?(RADEON)?','AMD Radeon',''], # ssd 
	['^(Ramaxel|RT|RM|RPF|RDM)','^Ramaxel','Ramaxel',''],
	['^(Ramsta|RT|SSD\d+GBS8)','^Ramsta','Ramsta',''],
	['^RAMOS','^RAMOS','RAmos',''],
	['^(Ramsta|R[1-9])','^Ramsta','Ramsta',''],
	['^RCESSD','^RCESSD','RCESSD',''],
	['^(Realtek|RTL)','^Realtek','Realtek',''],
	['^(Reletech)','^Reletech','Reletech',''], # id: P400 but that's too short
	['^RENICE','^RENICE','Renice',''],
	['^RevuAhn','^RevuAhn','RevuAhn',''],
	['^(Ricoh|R5)','^Ricoh','Ricoh',''],
	['^RIM[\s]','^RIM','RIM',''],
	['^(Rococo|ITE\b|IT\d{4})','^Rococo','Rococo',''],
	 #RTDMA008RAV2BWL comes with lenovo but don't know brand
	['^Runcore','^Runcore','Runcore',''],
	['^Rundisk','^Rundisk','RunDisk',''],
	['^RZX','^RZX\b','RZX',''],
	['^(S3Plus|S3\s?SSD)','^S3Plus','S3Plus',''],
	['^(Sabrent|Rocket)','^Sabrent','Sabrent',''],
	['^Sage','^Sage(\s?Micro)?','Sage Micro',''],
	['^SAMSWEET','^SAMSWEET','Samsweet',''],
	['^SandForce','^SandForce','SandForce',''],
	['^Sannobel','^Sannobel','Sannobel',''],
	['^(Sansa|fuse\b)','^Sansa','Sansa',''],
	# SATADOM can be innodisk or supermirco: dom == disk on module
	# SATAFIRM is an ssd failure message
	['^SCUDA','^SCUDA','SCUDA',''],
	['^(Sea\s?Tech|Transformer)','^Sea\s?Tech','Sea Tech',''],
	['^SigmaTel','^SigmaTel','SigmaTel',''],
	# DIAMOND_040_GB
	['^(SILICON\s?MOTION|SM\d|090c)','^(SILICON\s?MOTION|090c)','Silicon Motion',''],
	['(Silicon[\s-]?Power|^SP[CP]C|^Silicon|^Diamond|^HasTopSunlightpeed)','Silicon[\s-]?Power','Silicon Power',''],
	# simple drive could also maybe be hgst
	['^(Simple\s?Tech|Simple[\s-]?Drive)','^Simple\s?Tech','SimpleTech',''],
	['^(Simmtronics?|S[79]\d{2}|ZipX)','^Simmtronics?','Simmtronics',''],
	['^SINTECHI?','^SINTECHI?','SinTech (adapter)',''],
	['^SiS\b','^SiS','SiS',''],
	['Smartbuy','\s?Smartbuy','Smartbuy',''], # SSD Smartbuy 60GB; mSata Smartbuy 3
	# HFS128G39TND-N210A; seen nvme with name in middle
	['(SK\s?HYNIX|^HF[MS]|^H[BC]G|^HFB|^BC\d{3}|^SC[234]\d\d\sm?SATA|^SK[\s-]?\d{2,4})','\s?SK\s?HYNIX','SK Hynix',''], 
	['(hynix|^HAG\d|h[BC]8aP|PC\d{3})','hynix','Hynix',''],# nvme middle of string, must be after sk hynix
	['^SH','','Smart Modular Tech.',''],
	['^Skill','^Skill','Skill',''],
	['^(SMART( Storage Systems)?|TX)','^(SMART( Storage Systems)?)','Smart Storage Systems',''],
	['^Sobetter','^Sobetter','Sobetter',''],
	['^Solidata','^Solidata','Solidata',''],
	['^(SOLIDIGM|SSDPFK)','^SOLIDIGM\b','solidgm',''],
	['^(Sony|IM9|Microvalut|S[FR]-)','^Sony','Sony',''],
	['^SSK\b','^SSK','SSK',''],
	['^(SSSTC|CL1-)','^SSSTC','SSSTC',''],
	['^(SST|SG[AN])','^SST\b','SST',''],
	['^STE[CK]','^STE[CK]','sTec',''], # wd bought this one
	['^STORFLY','^STORFLY','StorFly',''],
	['\dSUN\d','^SUN(\sMicrosystems)?','Sun Microsystems',''],
	['^Sundisk','^Sundisk','Sundisk',''],
	['^SUNEAST','^SUNEAST','SunEast',''],
	['^SuperMicro','^SuperMicro','SuperMicro',''],
	['^Supersonic','^Supersonic','Supersonic',''],
	['^SuperSSpeed','^SuperSSpeed','SuperSSpeed',''],
	# NOTE: F[MNETU] not reliable, g.skill starts with FM too: 
	# Seagate ST skips STT. 
	['^(Super\s*Talent|STT|F[HTZ]M\d|PicoDrive|Teranova)','','Super Talent',''], 
	['^(SF|Swissbit)','^Swissbit','Swissbit',''],
	# ['^(SUPERSPEED)','^SUPERSPEED','SuperSpeed',''], # superspeed is a generic term
	['^(SXMicro|NF8)','^SXMicro','SXMicro',''],
	['^Taisu','^Taisu','Taisu',''],
	['^(TakeMS|ColorLine)','^TakeMS','TakeMS',''],
	['^Tammuz','^Tammuz','Tammuz',''],
	['^TANDBERG','^TANDBERG','Tanberg',''],
	['^(TC[\s-]*SUNBOW|X3\s\d+[GT])','^TC[\s-]*SUNBOW','TCSunBow',''],
	['^(TDK|TF[1-9]\d|LoR)','^TDK','TDK',''],
	['^TEAC','^TEAC','TEAC',''],
	['^(TEAM|T[\s-]?Create|CX[12]\b|L\d\s?Lite|T\d{3,}[A-Z]|TM\d|(Dark\s?)?L3\b|T[\s-]?Force)','^TEAM(\s*Group)?','TeamGroup',''],
	['^(Teclast|CoolFlash)','^Teclast','Teclast',''],
	['^(tecmiyo)','^tecmiyo','TECMIYO',''],
	['^Teelkoou','^Teelkoou','Teelkoou',''],
	['^Tele2','^Tele2','Tele2',''],
	['^Teleplan','^Teleplan','Teleplan',''],
	['^TEUTONS','^TEUTONS','TEUTONS',''],
	['^(Textorm)','^Textorm','Textorm',''], # B5 too short
	['^(T(&|\s?and\s?)?G\d{3})','^T&G\b','T&G',''],
	['^THU','^THU','THU',''],
	['^Tiger[\s_-]?Jet','^Tiger[\s_-]?Jet','TigerJet',''],
	['^Tigo','^Tigo','Tigo',''],
	['^(Timetec|35TT)','^Timetec','Timetec',''],
	['^TKD','^TKD','TKD',''],
	['^TopSunligt','^TopSunligt','TopSunligt',''], # is this a typo? hard to know
	['^TopSunlight','^TopSunlight','TopSunlight',''],
	['^TOROSUS','^TOROSUS','Torosus',''],
	['(Transcend|^((SSD\s|F)?TS|ESD\d|EZEX|USDU)|1307|JetDrive|JetFlash)','\b(Transcend|1307)\b','Transcend',''], 
	['^(TrekStor|DS (maxi|pocket)|DataStation)','^TrekStor','TrekStor',''],
	['^Turbox','^Turbox','Turbox',''],
	['^TurXun','^TurXun','TurXun',''],
	['^(TwinMOS|TW\d)','^TwinMOS','TwinMOS',''],
	# note: udisk means usb disk, it's not a vendor ID
	['^UDinfo','^UDinfo','UDinfo',''],
	['^UMAX','^UMAX','UMAX',''],
	['^UpGamer','^UpGamer','UpGamer',''],
	['^(UMIS|RP[IJ]TJ)','^UMIS','UMIS',''],
	['^USBTech','^USBTech','USBTech',''],
	['^(UNIC2)','^UNIC2','UNIC2',''],
	['^(UG|Unigen)','^Unigen','Unigen',''],
	['^(UNIREX)','^UNIREX','UNIREX',''],
	['^(UNITEK)','^UNITEK','UNITEK',''],
	['^(USBest|UT16)','^USBest','USBest',''],
	['^(OOS[1-9]|Utania)','Utania','Utania',''],
	['^U-TECH','U-TECH','U-Tech',''],
	['^(Value\s?Tech|VTP\d)','^Value\s?Tech','ValueTech',''],
	['^VBOX','','VirtualBox',''],
	['^(Veno|Scorp)','^Veno','Veno',''],
	['^(Verbatim|STORE\s?\'?N\'?\s?(FLIP|GO)|Vi[1-9]|OTG\s?Tiny)','^Verbatim','Verbatim',''],
	['^V-?GEN','^V-?GEN','V-Gen',''],
	['^VICK','VICK','VICK',''],
	['^V[\s-]?(7|Seven)','^V[\s-]?(7|Seven)\b','VSeven',''],
	['^(Victorinox|Swissflash)','^Victorinox','Victorinox',''],
	['^(Virtium|VTD)','^Virtium','Virtium',''],
	['^(Visipro|SDVP)','^Visipro','Visipro',''],
	['^VISIONTEK','^VISIONTEK','VisionTek',''],
	['^VMware','^VMware','VMware',''],
	['^(Vseky|Vaseky|V8\d{2})','^Vaseky','Vaseky',''], # ata-Vseky_V880_350G_
	['^(Walgreen|Infinitive)','^Walgreen','Walgreen',''],
	['^Walram','^Walram','WALRAM',''],
	['^Walton','^Walton','Walton',''],
	['^(Wearable|Air-?Stash)','^Wearable','Wearable',''],
	['^Wellcomm','^Wellcomm','Wellcomm',''],
	['^(wicgtyp|[MN][V]?900)','^wicgtyp','wicgtyp',''],
	['^Wilk','^Wilk','Wilk',''],
	['^(WinMemory|SWG\d)','^WinMemory','WinMemory',''],
	['^(Winton|WT\d{2})','^Winton','Winton',''],
	['^(WISE)','^WISE','WISE',''],
	['^WPC','^WPC','WPC',''], # WPC-240GB
	['^(Wortmann(\sAG)?|Terra\s?US)','^Wortmann(\sAG)?','Wortmann AG',''],
	['^(XDisk|X9\b)','^XDisk','XDisk',''],
	['^(XinTop|XT-)','^XinTop','XinTop',''],
	['^Xintor','^Xintor','Xintor',''],
	['^XPG','^XPG','XPG',''],
	['^XrayDisk','^XrayDisk','XrayDisk',''],
	['^Xstar','^Xstar','Xstar',''],
	['^(Xtigo)','^Xtigo','Xtigo',''],
	['^(XUM|HX\d)','^XUM','XUM',''],
	['^XUNZHE','^XUNZHE','XUNZHE',''],
	['^(Yangtze|ZhiTai|PC00[5-9]|SC00[1-9])','^Yangtze(\s*Memory)?','Yangtze Memory',''],
	['^(Yeyian|valk)','^Yeyian','Yeyian',''],
	['^(YingChu|YGC)','^YingChu','YingChu',''],
	['^YongzhenWeiye','^YongzhenWeiye','YongzhenWeiye',''],
	['^(YUCUN|R880)','^YUCUN','YUCUN',''],
	['^(ZALMAN|ZM\b)','^ZALMAN','Zalman',''],
	# Zao/J.Zau: marvell ssd controller
	['^ZXIC','^ZXIC','ZXIC',''],
	['^(Zebronics|ZEB)','^Zebronics','Zebronics',''],
	['^Zenfast','^Zenfast','Zenfast',''],
	['^Zenith','^Zenith','Zenith',''],
	['^ZEUSLAP','^ZEUSLAP','ZEUSLAP',''],
	['^ZEUSS','^ZEUSS','Zeuss',''],
	['^(Zheino|CHN|CNM)','^Zheino','Zheino',''],
	['^(Zotac|ZTSSD)','^Zotac','Zotac',''],
	['^ZOZT','^ZOZT','ZOZT',''],
	['^ZSPEED','^ZSPEED','ZSpeed',''],
	['^ZTC','^ZTC','ZTC',''],
	['^ZTE','^ZTE','ZTE',''],
	['^(ZY|ZhanYao)','^ZhanYao([\s-]?data)','ZhanYao',''],
	['^(ASMT|2115)','^ASMT','ASMT (case)',''],
	];
	eval $end if $b_log;
}
## END DISK VENDOR BLOCK ##

# receives space separated string that may or may not contain vendor data
sub disk_vendor {
	eval $start if $b_log;
	my ($model,$serial) = @_;
	my ($vendor) = ('');
	return if !$model;
	# 0 - match pattern; 1 - replace pattern; 2 - vendor print; 3 - serial pattern
	# Data URLs: inxi-resources.txt Section: DriveItem device_vendor()
	# $model = 'H10 HBRPEKNX0202A NVMe INTEL 512GB';
	# $model = 'SD Ultra 3D 1TB';
	# $model = 'ST8000DM004-2CX188_WCT193ZX';
	set_disk_vendors() if !$vendors;
	# prefilter this one, some usb enclosurs and wrong master/slave hdd show default
	$model =~ s/^Initio[\s_]//i;
	foreach my $row (@$vendors){
		if ($model =~ /$row->[0]/i || ($row->[3] && $serial && $serial =~ /$row->[3]/)){
			$vendor = $row->[2];
			# Usually we want to assign N/A at output phase, maybe do this logic there?
			if ($row->[1]){
				if ($model !~ m/$row->[1]$/i){
					$model =~ s/$row->[1]//i;
				}
				else {
					$model = 'N/A';
				}
			}
			$model =~ s/^[\/\[\s_-]+|[\/\s_-]+$//g;
			$model =~ s/\s\s/ /g;
			last;
		}
	}
	eval $end if $b_log;
	return [$vendor,$model];
}

# Normally hddtemp requires root, but you can set user rights in /etc/sudoers.
# args: 0: /dev/<disk> to be tested for
sub hdd_temp {
	eval $start if $b_log;
	my ($device) = @_;
	my ($path) = ('');
	my (@data,$hdd_temp);
	$hdd_temp = hdd_temp_sys($device) if !$force{'hddtemp'} && -e "/sys/block/$device";
	if (!$hdd_temp){
		$device = "/dev/$device";
		if ($device =~ /nvme/i){
			if (!$b_nvme){
				$b_nvme = 1;
				if ($path = main::check_program('nvme')){
					$nvme = $path;
				}
			}
			if ($nvme){
				$device =~ s/n[0-9]//;
				@data = main::grabber("$sudoas$nvme smart-log $device 2>/dev/null");
				foreach (@data){
					my @row = split(/\s*:\s*/, $_);
					next if !$row[0];
					# other rows may have: Temperature sensor 1 :
					if ($row[0] eq 'temperature'){
						$row[1] =~ s/\s*C//;
						$hdd_temp = $row[1];
						last;
					}
				}
			}
		}
		else {
			if (!$b_hddtemp){
				$b_hddtemp = 1;
				if ($path = main::check_program('hddtemp')){
					$hddtemp = $path;
				}
			}
			if ($hddtemp){
				$hdd_temp = (main::grabber("$sudoas$hddtemp -nq -u C $device 2>/dev/null"))[0];
			}
		}
		$hdd_temp =~ s/\s?(Celsius|C)$// if $hdd_temp;
	}
	eval $end if $b_log;
	return $hdd_temp;
}

sub hdd_temp_sys {
	eval $start if $b_log;
	my ($device) = @_;
	my ($hdd_temp,$hdd_temp_alt,%sensors,@data,@working);
	my ($holder,$index) = ('','');
	my $path = "/sys/block/$device/device";
	my $path_trimmed = Cwd::abs_path("/sys/block/$device");
	# slice out the part of path that gives us hwmon in earlier kernel drivetemp
	$path_trimmed =~ s%/(block|nvme)/.*$%% if $path_trimmed;
	print "device: $device path: $path\n path_trimmed: $path_trimmed\n" if $dbg[21];
	return if ! -e $path && (!$path_trimmed || ! -e "$path_trimmed/hwmon");
	# first type, trimmed block,nvme (ata and nvme), 5.9 kernel:
	# /sys/devices/pci0000:10/0000:10:08.1/0000:16:00.2/ata8/host7/target7:0:0/7:0:0:0/hwmon/hwmon5/
	# /sys/devices/pci0000:10/0000:10:01.2/0000:13:00.0/hwmon/hwmon0/ < nvme
	# /sys/devices/pci0000:00/0000:00:01.3/0000:01:00.1/ata2/host1/target1:0:0/1:0:0:0/hwmon/hwmon3/
	# second type, 5.10+ kernel:
	# /sys/devices/pci0000:20/0000:20:03.1/0000:21:00.0/nvme/nvme0/nvme0n1/device/hwmon1
	# /sys/devices/pci0000:00/0000:00:08.1/0000:0b:00.2/ata12/host11/target11:0:0/11:0:0:0/block/sdd/device/hwmon/hwmon1
	# we don't want these items: crit|max|min|lowest|highest
	# original kernel 5.8/9 match for nvme and sd, 5.10+ match for sd
	if (-e "$path_trimmed/hwmon/"){
		@data = main::globber("$path_trimmed/hwmon/hwmon*/temp*_{input,label}");
	}
	# this case only happens if path_trimmed case isn't there, but leave in case
	elsif (-e "$path/hwmon/"){
		@data = main::globber("$path/hwmon/hwmon*/temp*_{input,label}");
	}
	# current match for nvme, but fails for 5.8/9 kernel nvme
	else {
		@data = main::globber("$path/hwmon*/temp*_{input,label}");
	}
	# seeing long lag to read temp input files for some reason
	foreach (sort @data){
		# print "file: $_\n";
		# print(main::reader($_,'',0),"\n");
		$path = $_;
		# cleanup everything in front of temp, the path
		$path =~ s/^.*\///;
		@working = split('_', $path);
		if ($holder ne $working[0]){
			$holder = $working[0];
		}
		$sensors{$holder}->{$working[1]} = main::reader($_,'strip',0);
	}
	return if !%sensors;
	if (keys %sensors == 1){
		if ($sensors{$holder}->{'input'} && main::is_numeric($sensors{$holder}->{'input'})){
			$hdd_temp = $sensors{$holder}->{'input'};
		}
	}
	else {
		# nvme drives can have > 1 temp types, but composite is the one we want if there
		foreach (keys %sensors){
			next if !$sensors{$_}->{'input'} || !main::is_numeric($sensors{$_}->{'input'});
			if ($sensors{$_}->{'label'} && $sensors{$_}->{'label'} eq 'Composite'){
				$hdd_temp = $sensors{$_}->{'input'};
				last;
			}
			else{
				$hdd_temp_alt = $sensors{$_}->{'input'};
			}
		}
		$hdd_temp = $hdd_temp_alt if !defined $hdd_temp && defined $hdd_temp_alt;
	}
	$hdd_temp = sprintf("%.1f", $hdd_temp/1000) if $hdd_temp;
	main::log_data('data',"device: $device temp: $hdd_temp") if $b_log;
	main::log_data('dump','%sensors',\%sensors) if $b_log;
	print Data::Dumper::Dumper \%sensors if $dbg[21];
	eval $end if $b_log;
	return $hdd_temp;
}

# args: 0: block id
sub block_data {
	eval $start if $b_log;
	my ($id) = @_;
	# 0: logical block size 1: disk physical block size/partition block size;
	my ($block_log,$block_size) = (0,0);
	# my $path_size = "/sys/block/$id/size";
	my $path_log_block = "/sys/block/$id/queue/logical_block_size";
	my $path_phy_block = "/sys/block/$id/queue/physical_block_size";
	# legacy system path
	if (! -e $path_phy_block && -e "/sys/block/$id/queue/hw_sector_size"){
		$path_phy_block = "/sys/block/$id/queue/hw_sector_size";
	}
	$block_log = main::reader($path_log_block,'',0) if  -r $path_log_block;
	$block_size = main::reader($path_phy_block,'',0) if -r $path_phy_block;
	# print "l-b: $block_log p-b: $block_size raw: $size_raw\n";
	my $blocks = [$block_log,$block_size]; 
	main::log_data('dump','@blocks',$blocks) if $b_log;
	eval $end if $b_log;
	return $blocks;
}

sub drive_speed {
	eval $start if $b_log;
	my ($device) = @_;
	my ($b_nvme,$lanes,$speed);
	my $working = Cwd::abs_path("/sys/class/block/$device");
	# print "$working\n";
	if ($working){
		my ($id);
		# slice out the ata id:
		# /sys/devices/pci0000:00:11.0/ata1/host0/target0:
		if ($working =~ /^.*\/ata([0-9]+)\/.*/){
			$id = $1;
		}
		# /sys/devices/pci0000:00/0000:00:05.0/virtio1/block/vda
		elsif ($working =~ /^.*\/virtio([0-9]+)\/.*/){
			$id = $1;
		}
		# /sys/devices/pci0000:10/0000:10:01.2/0000:13:00.0/nvme/nvme0/nvme0n1
		elsif ($working =~ /^.*\/(nvme[0-9]+)\/.*/){
			$id = $1;
			$b_nvme = 1;
		}
		# do host last because the strings above might have host as well as their search item
		# 0000:00:1f.2/host3/target3: increment by 1 sine ata starts at 1, but host at 0
		elsif ($working =~ /^.*\/host([0-9]+)\/.*/){
			$id = $1 + 1 if defined $1;
		}
		# print "$working $id\n";
		if (defined $id){
			if ($b_nvme){
				$working = "/sys/class/nvme/$id/device/max_link_speed";
				$speed = main::reader($working,'',0) if -r $working;
				if (defined $speed && $speed =~ /([0-9\.]+)\sGT\/s/){
					$speed = $1;
					# pcie1: 2.5 GT/s; pcie2: 5.0 GT/s; pci3: 8 GT/s
					# NOTE: PCIe 3 stopped using the 8b/10b encoding but a sample pcie3 nvme has 
					# rated speed of GT/s * .8 anyway. GT/s * (128b/130b)
					$speed = ($speed <= 5) ? $speed * .8 : $speed * 128/130; 
					$speed = sprintf("%.1f",$speed) if $speed;
					$working = "/sys/class/nvme/$id/device/max_link_width";
					$lanes = main::reader($working,'',0) if -r $working;
					$lanes ||= 1;
					# https://www.edn.com/electronics-news/4380071/What-does-GT-s-mean-anyway-
					# https://www.anandtech.com/show/2412/2
					# http://www.tested.com/tech/457440-theoretical-vs-actual-bandwidth-pci-express-and-thunderbolt/
					# PCIe 1,2 use “8b/10b” encoding: eight bits are encoded into a 10-bit symbol
					# PCIe 3,4,5 use "128b/130b" encoding: 128 bits are encoded into a 130 bit symbol
					$speed = ($speed * $lanes) . " Gb/s";
				}
			}
			else {
				$working = "/sys/class/ata_link/link$id/sata_spd";
				$speed = main::reader($working,'',0) if -r $working;
				$speed = main::clean_disk($speed) if $speed;
				$speed =~ s/Gbps/Gb\/s/ if $speed;
			}
		}
	}
	# print "$working $speed\n";
	eval $end if $b_log;
	return [$speed,$lanes];
}
}

## GraphicItem 
{