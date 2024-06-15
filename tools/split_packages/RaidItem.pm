package RaidItem;

sub get {
	eval $start if $b_log;
	my ($hardware_raid,$key1,$val1);
	my $num = 0;
	my $rows = [];
	$hardware_raid = hw_data() if $use{'hardware-raid'} || $fake{'raid-hw'};
	raid_data() if !$loaded{'raid'};
	# print 'get btrfs: ', Data::Dumper::Dumper \@btrfs_raid;
	# print 'get lvm: ', Data::Dumper::Dumper \@lvm_raid;
	# print 'get md: ', Data::Dumper::Dumper \@md_raid;
	# print 'get zfs: ', Data::Dumper::Dumper \@zfs_raid;
	if (!@btrfs_raid && !@lvm_raid && !@md_raid && !@zfs_raid && !@soft_raid && 
	!$hardware_raid){
		if ($show{'raid-forced'}){
			$key1 = 'Message';
			$val1 = main::message('raid-data');
		}
	}
	else {
		if ($hardware_raid){
			hw_output($rows,$hardware_raid);
		}
		if (@btrfs_raid){
			btrfs_output($rows);
		}
		if (@lvm_raid){
			lvm_output($rows);
		}
		if (@md_raid){
			md_output($rows);
		}
		if (@soft_raid){
			soft_output($rows);
		}
		if (@zfs_raid){
			zfs_output($rows);
		}
	}
	if (!@$rows && $key1){
		@$rows = ({main::key($num++,0,1,$key1) => $val1,});
	}
	eval $end if $b_log;
	return $rows;
}

sub hw_output {
	eval $start if $b_log;
	my ($rows,$hardware_raid) = @_;
	my ($j,$num) = (0,0);
	foreach my $row (@$hardware_raid){
		$num = 1;
		my $device = ($row->{'device'}) ? $row->{'device'}: 'N/A';
		my $driver = ($row->{'driver'}) ? $row->{'driver'}: 'N/A';
		push(@$rows, {
		main::key($num++,1,1,'Hardware') => $device,
		});
		$j = scalar @$rows - 1;
		$rows->[$j]{main::key($num++,0,2,'vendor')} = $row->{'vendor'} if $row->{'vendor'};
		$rows->[$j]{main::key($num++,1,2,'driver')} = $driver;
		if ($extra > 0){
			$row->{'driver-version'} ||= 'N/A';
			$rows->[$j]{main::key($num++,0,3,'v')} = $row->{'driver-version'};
			if ($extra > 2){
				my $port= ($row->{'port'}) ? $row->{'port'}: 'N/A' ;
				$rows->[$j]{main::key($num++,0,2,'port')} = $port;
			}
			my $bus_id = (defined $row->{'bus-id'} && defined $row->{'sub-id'}) ? "$row->{'bus-id'}.$row->{'sub-id'}": 'N/A' ;
			$rows->[$j]{main::key($num++,0,2,'bus-ID')} = $bus_id;
		}
		if ($extra > 1){
			my $chip_id = main::get_chip_id($row->{'vendor-id'},$row->{'chip-id'});
			$rows->[$j]{main::key($num++,0,2,'chip-ID')} = $chip_id;
		}
		if ($extra > 2){
			$row->{'rev'} = 'N/A' if !defined $row->{'rev'}; # could be 0
			$rows->[$j]{main::key($num++,0,2,'rev')} = $row->{'rev'};
			$rows->[$j]{main::key($num++,0,2,'class-ID')} = $row->{'class-id'} if $row->{'class-id'};
		}
	}
	eval $end if $b_log;
	# print Data::Dumper::Dumper $rows;
}

sub btrfs_output {
	eval $start if $b_log;
	my $rows = $_[0];
	my (@components,@good);
	my ($size);
	my ($j,$num) = (0,0);
	foreach my $row (sort {$a->{'id'} cmp $b->{'id'}} @btrfs_raid){
		$j = scalar @$rows;
		$rows->[$j]{main::key($num++,1,2,'Components')} = '';
		my $b_bump;
		components_output('lvm','Online',$rows,\@good,\$j,\$num,\$b_bump);
		components_output('lvm','Meta',$rows,\@components,\$j,\$num,\$b_bump);
	}
	eval $end if $b_log;
	# print Data::Dumper::Dumper $rows;
}

sub lvm_output {
	eval $start if $b_log;
	my $rows = $_[0];
	my (@components,@good,@components_meta);
	my ($size);
	my ($j,$num) = (0,0);
	foreach my $row (sort {$a->{'id'} cmp $b->{'id'}} @lvm_raid){
		$j = scalar @$rows;
		push(@$rows, {
		main::key($num++,1,1,'Device') => $row->{'id'},
		});
		if ($b_admin && $row->{'maj-min'}){
			$rows->[$j]{main::key($num++,0,2,'maj-min')} = $row->{'maj-min'};
		}
		$rows->[$j]{main::key($num++,0,2,'type')} = $row->{'type'};
		$rows->[$j]{main::key($num++,0,2,'level')} = $row->{'level'};
		$size = ($row->{'size'}) ? main::get_size($row->{'size'},'string'): 'N/A';
		$rows->[$j]{main::key($num++,0,2,'size')} = $size;
		if ($row->{'raid-sync'}){
			$rows->[$j]{main::key($num++,0,2,'sync')} = $row->{'raid-sync'};
		}
		if ($extra > 0){
			$j = scalar @$rows;
			$num = 1;
			$rows->[$j]{main::key($num++,1,2,'Info')} = '';
			if (defined $row->{'stripes'}){
				$rows->[$j]{main::key($num++,0,3,'stripes')} = $row->{'stripes'};
			}
			if (defined $row->{'raid-mismatches'} && ($extra > 1 || $row->{'raid-mismatches'} > 0)){
				$rows->[$j]{main::key($num++,0,3,'mismatches')} = $row->{'raid-mismatches'};
			}
			if (defined $row->{'copy-percent'} && ($extra > 1 || $row->{'copy-percent'} < 100)){
				$rows->[$j]{main::key($num++,0,3,'copied')} = ($row->{'copy-percent'} + 0) . '%';
			}
			if ($row->{'vg'}){
				$rows->[$j]{main::key($num++,1,3,'v-group')} = $row->{'vg'};
			}
			$size = ($row->{'vg-size'}) ? main::get_size($row->{'vg-size'},'string') : 'N/A';
			$rows->[$j]{main::key($num++,0,4,'vg-size')} = $size;
			$size = ($row->{'vg-free'}) ? main::get_size($row->{'vg-free'},'string') : 'N/A';
			$rows->[$j]{main::key($num++,0,4,'vg-free')} = $size;
		}
		@components = (ref $row->{'components'} eq 'ARRAY') ? @{$row->{'components'}} : ();
		@good = ();
		@components_meta = ();
		foreach my $item (sort { $a->[0] cmp $b->[0]} @components){
			if ($item->[4] =~ /_rmeta/){
				push(@components_meta, $item);
			}
			else {
				push(@good, $item);
			}
		}
		$j = scalar @$rows;
		$rows->[$j]{main::key($num++,1,2,'Components')} = '';
		my $b_bump;
		components_output('lvm','Online',$rows,\@good,\$j,\$num,\$b_bump);
		components_output('lvm','Meta',$rows,\@components_meta,\$j,\$num,\$b_bump);
	}
	eval $end if $b_log;
	# print Data::Dumper::Dumper $rows;
}

sub md_output {
	eval $start if $b_log;
	my $rows = $_[0];
	my (@components,@good,@failed,@inactive,@spare,@temp);
	my ($blocks,$chunk,$level,$report,$size,$status);
	my ($j,$num) = (0,0);
	# print Data::Dumper::Dumper \@md_raid;
	if ($extra > 2 && $md_raid[0]->{'supported-levels'}){
		push(@$rows, {
		main::key($num++,0,1,'Supported mdraid levels') => $md_raid[0]->{'supported-levels'},
		});
	}
	foreach my $row (sort {$a->{'id'} cmp $b->{'id'}} @md_raid){
		$j = scalar @$rows;
		next if !%$row;
		$num = 1;
		$level = (defined $row->{'level'}) ? $row->{'level'} : 'linear';
		push(@$rows, {
		main::key($num++,1,1,'Device') => $row->{'id'},
		});
		if ($b_admin && $row->{'maj-min'}){
			$rows->[$j]{main::key($num++,0,2,'maj-min')} = $row->{'maj-min'};
		}
		$rows->[$j]{main::key($num++,0,2,'type')} = $row->{'type'};
		$rows->[$j]{main::key($num++,0,2,'level')} = $level;
		$rows->[$j]{main::key($num++,0,2,'status')} = $row->{'status'};
		if ($row->{'details'}{'state'}){
			$rows->[$j]{main::key($num++,0,2,'state')} = $row->{'details'}{'state'};
		}
		if ($row->{'size'}){
			$size = main::get_size($row->{'size'},'string');
		}
		else {
			$size = (!$b_root && !@lsblk) ? main::message('root-required'): 'N/A';
		}
		$rows->[$j]{main::key($num++,0,2,'size')} = $size;
		$report = ($row->{'report'}) ? $row->{'report'}: '';
		$report .= " $row->{'u-data'}" if $report; 
		$report ||= 'N/A';
		if ($extra == 0){
			# print "here 0\n";
			$rows->[$j]{main::key($num++,0,2,'report')} = $report;
		}
		if ($extra > 0){
			$j = scalar @$rows;
			$num = 1;
			$rows->[$j]{main::key($num++,1,2,'Info')} = '';
			#$rows->[$j]{main::key($num++,0,3,'raid')} = $raid;
			$rows->[$j]{main::key($num++,0,3,'report')} = $report;
			$blocks = ($row->{'blocks'}) ? $row->{'blocks'} : 'N/A';
			$rows->[$j]{main::key($num++,0,3,'blocks')} = $blocks;
			$chunk = ($row->{'chunk-size'}) ? $row->{'chunk-size'} : 'N/A';
			$rows->[$j]{main::key($num++,0,3,'chunk-size')} = $chunk;
			if ($extra > 1){
				if ($row->{'bitmap'}){
					$rows->[$j]{main::key($num++,0,3,'bitmap')} = $row->{'bitmap'};
				}
				if ($row->{'super-block'}){
					$rows->[$j]{main::key($num++,0,3,'super-blocks')} = $row->{'super-block'};
				}
				if ($row->{'algorithm'}){
					$rows->[$j]{main::key($num++,0,3,'algorithm')} = $row->{'algorithm'};
				}
			}
		}
		@components = (ref $row->{'components'} eq 'ARRAY') ? @{$row->{'components'}} : ();
		@good = ();
		@failed = ();
		@inactive = ();
		@spare = ();
		# @spare = split(/\s+/, $row->{'unused'}) if $row->{'unused'};
		# print Data::Dumper::Dumper \@components;
		foreach my $item (sort { $a->[1] <=> $b->[1]} @components){
			if (defined $item->[2] && $item->[2] =~ /^(F)$/){
				push(@failed,$item);
			}
			elsif (defined $item->[2] && $item->[2] =~ /(S)$/){
				push(@spare,$item);
			}
			elsif ($row->{'status'} && $row->{'status'} eq 'inactive'){
				push(@inactive,$item);
			}
			else {
				push(@good,$item);
			}
		}
		$j = scalar @$rows;
		$rows->[$j]{main::key($num++,1,2,'Components')} = '';
		my $b_bump;
		components_output('mdraid','Online',$rows,\@good,\$j,\$num,\$b_bump);
		components_output('mdraid','Failed',$rows,\@failed,\$j,\$num,\$b_bump);
		components_output('mdraid','Inactive',$rows,\@inactive,\$j,\$num,\$b_bump);
		components_output('mdraid','Spare',$rows,\@spare,\$j,\$num,\$b_bump);
		if ($row->{'recovery-percent'}){
			$j = scalar @$rows;
			$num = 1;
			my $percent = $row->{'recovery-percent'};
			if ($extra > 1 && $row->{'progress-bar'}){
				$percent .= " $row->{'progress-bar'}"
			}
			$rows->[$j]{main::key($num++,1,2,'Recovering')} = $percent;
			my $finish = ($row->{'recovery-finish'})?$row->{'recovery-finish'} : 'N/A';
			$rows->[$j]{main::key($num++,0,3,'time-remaining')} = $finish;
			if ($extra > 0){
				if ($row->{'sectors-recovered'}){
					$rows->[$j]{main::key($num++,0,3,'sectors')} = $row->{'sectors-recovered'};
				}
			}
			if ($extra > 1 && $row->{'recovery-speed'}){
				$rows->[$j]{main::key($num++,0,3,'speed')} = $row->{'recovery-speed'};
			}
		}
	}
	eval $end if $b_log;
	# print Data::Dumper::Dumper $rows;
}

sub soft_output {
	eval $start if $b_log;
	my $rows = $_[0];
	my (@components,@good,@failed,@offline,@rebuild,@temp);
	my ($size);
	my ($j,$num) = (0,0);
	if (@soft_raid && $alerts{'bioctl'}->{'action'} eq 'permissions'){
		push(@$rows,{
		main::key($num++,1,1,'Message') => main::message('root-item-incomplete','softraid'),
		});
	}
	# print Data::Dumper::Dumper \@soft_raid;
	foreach my $row (sort {$a->{'id'} cmp $b->{'id'}} @soft_raid){
		$j = scalar @$rows;
		next if !%$row;
		$num = 1;
		push(@$rows, {
		main::key($num++,1,1,'Device') => $row->{'id'},
		});
		$row->{'level'} ||= 'N/A';
		$rows->[$j]{main::key($num++,0,2,'type')} = $row->{'type'};
		$rows->[$j]{main::key($num++,0,2,'level')} = $row->{'level'};
		$rows->[$j]{main::key($num++,0,2,'status')} = $row->{'status'};
		if ($row->{'state'}){
			$rows->[$j]{main::key($num++,0,2,'state')} = $row->{'state'};
		}
		if ($row->{'size'}){
			$size = main::get_size($row->{'size'},'string');
		}
		$size ||= 'N/A';
		$rows->[$j]{main::key($num++,0,2,'size')} = $size;
		@components = (ref $row->{'components'} eq 'ARRAY') ? @{$row->{'components'}} : ();
		@good = ();
		@failed = ();
		@offline = ();
		@rebuild = ();
		foreach my $item (sort { $a->[1] <=> $b->[1]} @components){
			if (defined $item->[2] && $item->[2] eq 'failed'){
				push(@failed,$item);
			}
			elsif (defined $item->[2] && $item->[2] eq 'offline'){
				push(@offline,$item);
			}
			elsif (defined $item->[2] && $item->[2] eq 'rebuild'){
				push(@rebuild,$item);
			}
			else {
				push(@good,$item);
			}
		}
		$j = scalar @$rows;
		$rows->[$j]{main::key($num++,1,2,'Components')} = '';
		my $b_bump;
		components_output('softraid','Online',$rows,\@good,\$j,\$num,\$b_bump);
		components_output('softraid','Failed',$rows,\@failed,\$j,\$num,\$b_bump);
		components_output('softraid','Rebuild',$rows,\@rebuild,\$j,\$num,\$b_bump);
		components_output('softraid','Offline',$rows,\@offline,\$j,\$num,\$b_bump);
	}
	eval $end if $b_log;
	# print Data::Dumper::Dumper $rows;
}

sub zfs_output {
	eval $start if $b_log;
	my $rows = $_[0];
	my (@arrays,@arrays_holder,@components,@good,@failed,@spare);
	my ($allocated,$available,$level,$size,$status);
	my ($b_row_1_sizes);
	my ($j,$num) = (0,0);
	# print Data::Dumper::Dumper \@zfs_raid;
	foreach my $row (sort {$a->{'id'} cmp $b->{'id'}} @zfs_raid){
		$j = scalar @$rows;
		$b_row_1_sizes = 0;
		next if !%$row;
		$num = 1;
		push(@$rows, {
		main::key($num++,1,1,'Device') => $row->{'id'},
		main::key($num++,0,2,'type') => $row->{'type'},
		main::key($num++,0,2,'status') => $row->{'status'},
		});
		$size = ($row->{'raw-size'}) ? main::get_size($row->{'raw-size'},'string') : '';
		$available = main::get_size($row->{'raw-free'},'string',''); # could be zero free
		if ($extra > 2){
			$allocated = ($row->{'raw-allocated'}) ? main::get_size($row->{'raw-allocated'},'string') : '';
		}
		@arrays = @{$row->{'arrays'}};
		@arrays = grep {defined $_} @arrays;
		@arrays_holder = @arrays;
		my $count = scalar @arrays;
		if (!defined $arrays[0]->{'level'}){
			$level = 'linear';
			$rows->[$j]{main::key($num++,0,2,'level')} = $level;
		}
		elsif ($count < 2 && $arrays[0]->{'level'}){
			$rows->[$j]{main::key($num++,0,2,'level')} = $arrays[0]->{'level'};
		}
		if ($size || $available || $allocated){
			$rows->[$j]{main::key($num++,1,2,'raw')} = '';
			if ($size){
				# print "here 0\n";
				$rows->[$j]{main::key($num++,0,3,'size')} = $size;
				$size = '';
				$b_row_1_sizes = 1;
			}
			if ($available){
				$rows->[$j]{main::key($num++,0,3,'free')} = $available;
				$available = '';
				$b_row_1_sizes = 1;
			}
			if ($allocated){
				$rows->[$j]{main::key($num++,0,3,'allocated')} = $allocated;
				$allocated = '';
			}
		}
		if ($row->{'zfs-size'}){
			$rows->[$j]{main::key($num++,1,2,'zfs-fs')} = '';
			$rows->[$j]{main::key($num++,0,3,'size')} = main::get_size($row->{'zfs-size'},'string');
			$rows->[$j]{main::key($num++,0,3,'free')} = main::get_size($row->{'zfs-free'},'string');
		}
		foreach my $row2 (@arrays){
			if ($count > 1){
				$j = scalar @$rows;
				$num = 1;
				$size = ($row2->{'raw-size'}) ? main::get_size($row2->{'raw-size'},'string') : 'N/A';
				$available = ($row2->{'raw-free'}) ? main::get_size($row2->{'raw-free'},'string') : 'N/A';
				$level = (defined $row2->{'level'}) ? $row2->{'level'}: 'linear';
				$status = ($row2->{'status'}) ? $row2->{'status'}: 'N/A';
				push(@$rows, {
				main::key($num++,1,2,'Array') => $level,
				main::key($num++,0,3,'status') => $status,
				main::key($num++,1,3,'raw') => '',
				main::key($num++,0,4,'size') => $size,
				main::key($num++,0,4,'free') => $available,
				});
			}
			# items like cache may have one component, with a size on that component
			elsif (!$b_row_1_sizes){
				# print "here $count\n";
				$size = ($row2->{'raw-size'}) ? main::get_size($row2->{'raw-size'},'string') : 'N/A';
				$available = ($row2->{'raw-free'}) ? main::get_size($row2->{'raw-free'},'string') : 'N/A';
				$rows->[$j]{main::key($num++,1,2,'raw')} = '';
				$rows->[$j]{main::key($num++,0,3,'size')} = $size;
				$rows->[$j]{main::key($num++,0,3,'free')} = $available;
				if ($extra > 2){
					$allocated = ($row2->{'raw-allocated'}) ? main::get_size($row2->{'raw-allocated'},'string') : '';
					if ($allocated){
						$rows->[$j]{main::key($num++,0,3,'allocated')} = $allocated;
					}
				}
			}
			@components = (ref $row2->{'components'} eq 'ARRAY') ? @{$row2->{'components'}} : ();
			@failed = ();
			@spare = ();
			@good = ();
			# @spare = split(/\s+/, $row->{'unused'}) if $row->{'unused'};
			foreach my $item (sort { $a->[0] cmp $b->[0]} @components){
				if (defined $item->[3] && $item->[3] =~ /^(DEGRADED|FAULTED|UNAVAIL)$/){
					push(@failed, $item);
				}
				elsif (defined $item->[3] && $item->[3] =~ /(AVAIL|OFFLINE|REMOVED)$/){
					push(@spare, $item);
				}
				# note: spares in use show: INUSE but technically it's still a spare,
				# but since it's in use, consider it online.
				else {
					push(@good, $item);
				}
			}
			$j = scalar @$rows;
			$rows->[$j]{main::key($num++,1,3,'Components')} = '';
			my $b_bump;
			components_output('zfs','Online',$rows,\@good,\$j,\$num,\$b_bump);
			components_output('zfs','Failed',$rows,\@failed,\$j,\$num,\$b_bump);
			components_output('zfs','Available',$rows,\@spare,\$j,\$num,\$b_bump);
		}
	}
	eval $end if $b_log;
	# print Data::Dumper::Dumper $rows;
}

# Most key stuff passed by ref, and is changed on the fly
sub components_output {
	eval $start if $b_log;
	my ($type,$item,$rows,$array,$j,$num,$b_bump) = @_;
	return if !@$array && $item ne 'Online';
	my ($extra1,$extra2,$f1,$f2,$f3,$f4,$f5,$k,$k1,$key1,$l1,$l2,$l3);
	if ($type eq 'btrfs'){
	
	}
	elsif ($type eq 'lvm'){
		($f1,$f2,$f3,$f4,$f5,$l1,$l2,$l3) = (1,2,3,4,5,3,4,5);
		$k = 1;
		$extra1 = 'mapped';
		$extra2 = 'dev';
	}
	elsif ($type eq 'mdraid'){
		($f1,$f2,$f3,$f4,$k1,$l1,$l2,$l3) = (3,4,5,6,1,3,4,5);
		$extra1 = 'mapped';
		$k = 1 if $item eq 'Inactive';
	}
	elsif ($type eq 'softraid'){
		($f1,$f2,$f3,$f4,$k1,$l1,$l2,$l3) = (1,10,10,3,5,3,4,5);
		$extra1 = 'device';
		$k = 1;
	}
	elsif ($type eq 'zfs'){
		($f1,$f2,$f3,$l1,$l2,$l3) = (1,2,3,4,5,6);
		$k = 1;
	}
	# print "item: $item\n";
	$$j++ if $$b_bump;
	$$b_bump = 0;
	my $good = ($item eq 'Online' && !@$array) ? 'N/A' : '';
	$rows->[$$j]{main::key($$num++,1,$l1,$item)} = $good;
	#$$j++ if $b_admin; 
	# print Data::Dumper::Dumper $array;
	foreach my $device (@$array){
		next if ref $device ne 'ARRAY';
		# if ($b_admin && $device->[$f1] && $device->[$f2]){
		if ($b_admin){
			$$j++;
			$$b_bump = 1;
			$$num = 1;
		}
		$key1 = (defined $k1 && defined $device->[$k1]) ? $device->[$k1] : $k++;
		$rows->[$$j]{main::key($$num++,1,$l2,$key1)} = $device->[0];
		if ($b_admin && $device->[$f2]){
			$rows->[$$j]{main::key($$num++,0,$l3,'maj-min')} = $device->[$f2];
		}
		if ($b_admin && $device->[$f1]){
			my $size = main::get_size($device->[$f1],'string');
			$rows->[$$j]{main::key($$num++,0,$l3,'size')} = $size;
		}
		if ($b_admin && $device->[$f3]){
			$rows->[$$j]{main::key($$num++,0,$l3,'state')} = $device->[$f3];
		}
		if ($b_admin && $extra1 && $device->[$f4]){
			$rows->[$$j]{main::key($$num++,0,$l3,$extra1)} = $device->[$f4];
		}
		if ($b_admin && $extra2 && $device->[$f5]){
			$rows->[$$j]{main::key($$num++,0,$l3,$extra2)} = $device->[$f5];
		}
	}
	eval $end if $b_log;
}

sub raid_data {
	eval $start if $b_log;
	LsblkData::set() if !$bsd_type && !$loaded{'lsblk'};
	main::set_mapper() if !$bsd_type && !$loaded{'mapper'};
	PartitionData::set() if !$bsd_type && !$loaded{'partition-data'};
	my (@data);
	$loaded{'raid'} = 1;
	if ($fake{'raid-btrfs'} || 
	 ($alerts{'btrfs'}->{'action'} && $alerts{'btrfs'}->{'action'} eq 'use')){
		@btrfs_raid = btrfs_data();
	}
	if ($fake{'raid-lvm'} || 
	 ($alerts{'lvs'}->{'action'} && $alerts{'lvs'}->{'action'} eq 'use')){
		@lvm_raid = lvm_data();
	}
	if ($fake{'raid-md'} || (my $file = $system_files{'proc-mdstat'})){
		@md_raid = md_data($file);
	}
	if ($fake{'raid-soft'} || $sysctl{'softraid'}){
		DiskDataBSD::set() if !$loaded{'disk-data-bsd'};
		@soft_raid = soft_data();
	}
	if ($fake{'raid-zfs'} || (my $path = main::check_program('zpool'))){
		DiskDataBSD::set() if $bsd_type && !$loaded{'disk-data-bsd'};
		@zfs_raid = zfs_data($path);
	}
	eval $end if $b_log;
}

# 0: type
# 1: type_id
# 2: bus_id
# 3: sub_id
# 4: device
# 5: vendor_id
# 6: chip_id
# 7: rev
# 8: port
# 9: driver
# 10: modules
sub hw_data {
	eval $start if $b_log;
	return if !$devices{'hwraid'};
	my ($driver,$vendor,$hardware_raid);
	foreach my $working (@{$devices{'hwraid'}}){
		$driver = ($working->[9]) ? lc($working->[9]): '';
		$driver =~ s/-/_/g if $driver;
		my $driver_version = ($driver) ? main::get_module_version($driver): '';
		if ($extra > 2 && $use{'pci-tool'} && $working->[11]){
			$vendor = main::get_pci_vendor($working->[4],$working->[11]);
		}
		push(@$hardware_raid, {
		'class-id' => $working->[1],
		'bus-id' => $working->[2],
		'chip-id' => $working->[6],
		'device' => $working->[4],
		'driver' => $driver,
		'driver-version' => $driver_version,
		'port' => $working->[8],
		'rev' => $working->[7],
		'sub-id' => $working->[3],
		'vendor-id' => $working->[5],
		'vendor' => $vendor,
		});
	}
	# print Data::Dumper::Dumper $hardware_raid;
	main::log_data('dump','@$hardware_raid',$hardware_raid) if $b_log;
	eval $end if $b_log;
	return $hardware_raid;
}

# Placeholder, if they ever get useful tools
sub btrfs_data {
	eval $start if $b_log;
	my (@btraid,@working);
	if ($fake{'raid-btrfs'}){
	
	}
	else {
	
	}
	print Data::Dumper::Dumper \@working if $dbg[37];
	print Data::Dumper::Dumper \@btraid if $dbg[37];
	main::log_data('dump','@lvraid',\@btraid) if $b_log;
	eval $end if $b_log;
	return @btraid;
}

sub lvm_data {
	eval $start if $b_log;
	LogicalItem::lvm_data() if !$loaded{'logical-data'};
	return if !@lvm;
	my (@lvraid,$maj_min,$vg_used,@working);
	foreach my $item (@lvm){
		next if $item->{'segtype'} && $item->{'segtype'} !~ /^raid/;
		my (@components,$dev,$maj_min,$vg_used);
		# print Data::Dumper::Dumper $item;
		if ($item->{'lv_kernel_major'} . ':' . $item->{'lv_kernel_minor'}){
			$maj_min = $item->{'lv_kernel_major'} . ':' . $item->{'lv_kernel_minor'};
		}
		if (defined $item->{'vg_free'} && defined $item->{'vg_size'}){
			$vg_used = ($item->{'vg_size'} - $item->{'vg_free'});
		}
		$raw_logical[0] += $item->{'lv_size'} if $item->{'lv_size'};
		@working = main::globber("/sys/dev/block/$maj_min/slaves/*") if $maj_min;
		@working = map {$_ =~ s|^/.*/||; $_;} @working if @working;
		foreach my $part (@working){
			my ($dev,$maj_min,$mapped,$size);
			if (@proc_partitions){
				my $info = PartitionData::get($part);
				$maj_min = $info->[0] . ':' . $info->[1] if defined $info->[1];
				$size = $info->[2];
				$raw_logical[1] += $size if $part =~ /^dm-/ && $size;
				my @data = main::globber("/sys/dev/block/$maj_min/slaves/*") if $maj_min;
				@data = map {$_ =~ s|^/.*/||; $_;} @data if @data;
				$dev = join(',', @data) if @data;
			}
			$mapped = $dmmapper{$part} if %dmmapper;
			push(@components, [$part,$size,$maj_min,undef,$mapped,$dev],);
		}
		if ($item->{'segtype'}){
			if ($item->{'segtype'} eq 'raid1'){$item->{'segtype'} = 'mirror';}
			else {$item->{'segtype'} =~ s/^raid([0-9]+)/raid-$1/;}
		}
		push(@lvraid, {
		'components' => \@components,
		'copy-percent' => $item->{'copy_percent'},
		'id' => $item->{'lv_name'},
		'level' => $item->{'segtype'},
		'maj-min' => $maj_min,
		'raid-mismatches' =>  $item->{'raid_mismatch_count'},
		'raid-sync' =>  $item->{'raid_sync_action'},
		'size' => $item->{'lv_size'},
		'stripes' => $item->{'stripes'},
		'type' => $item->{'vg_fmt'},
		'vg' => $item->{'vg_name'},
		'vg-free' => $item->{'vg_free'},
		'vg-size' => $item->{'vg_size'},
		'vg-used' => $vg_used,
		});
	}
	print Data::Dumper::Dumper \@lvraid if $dbg[37];
	main::log_data('dump','@lvraid',\@lvraid) if $b_log;
	eval $end if $b_log;
	return @lvraid;
}

sub md_data {
	eval $start if $b_log;
	my ($mdstat) = @_;
	my $j = 0;
	if ($fake{'raid-md'}){
		#$mdstat = "$fake_data_dir/raid-logical/md/md-4-device-1.txt";
		#$mdstat = "$fake_data_dir/raid-logical/md/md-rebuild-1.txt";
		#$mdstat = "$fake_data_dir/raid-logical/md/md-2-mirror-fserver2-1.txt";
		#$mdstat = "$fake_data_dir/raid-logical/md/md-2-raid10-abucodonosor.txt";
		#$mdstat = "$fake_data_dir/raid-logical/md/md-2-raid10-ant.txt";
		#$mdstat = "$fake_data_dir/raid-logical/md/md-inactive-weird-syntax.txt";
		#$mdstat = "$fake_data_dir/raid-logical/md/md-inactive-active-syntax.txt";
		#$mdstat = "$fake_data_dir/raid-logical/md/md-inactive-active-spare-syntax.txt";
	}
	my @working = main::reader($mdstat,'strip');
	# print Data::Dumper::Dumper \@working;
	my (@mdraid,@temp,$b_found,$system,$unused);
	# NOTE: a system with empty mdstat will not show these values
	if ($working[0] && $working[0] =~ /^Personalities/){
		$system = (split(/:\s*/, $working[0]))[1];
		$system =~ s/\[|\]//g if $system;
		shift @working;
	}
	if ($working[-1] && $working[-1] =~ /^unused\sdevices/){
		$unused = (split(/:\s*/, $working[-1]))[1];
		$unused =~ s/<|>|none//g if $unused;
		pop @working;
	}
	foreach (@working){
		$_ =~ s/\s*:\s*/:/;
		# print "$_\n";
		# md0 : active raid1 sdb1[2] sda1[0]
		# md126 : active (auto-read-only) raid1 sdq1[0]
		# md127 : inactive sda0
		# md1 : inactive sda1[0] sdd1[3] sdc1[2] sdb1[1]
		# if (/^(md[0-9]+)\s*:\s*([^\s]+)(\s\([^)]+\))?\s([^\s]+)\s(.*)/){
		if (/^(md[0-9]+)\s*:\s*([\S]+)(\s\([^)]+\))?/){
			my ($component_string,$details,$device,$id,$level,$maj_min,$part,$size,$status);
			my (@components);
			$id = $1;
			$status = $2;
			if (/^(md[0-9]+)\s*:\s*([\S]+)(\s\([^)]+\))?\s((faulty|linear|multipath|raid)[\S]*)\s(.*)/){
				$level = $4;
				$component_string = $6;
				$level =~ s/^raid1$/mirror/;
				$level =~ s/^raid/raid-/; 
				$level = 'mirror' if $level eq '1';
			}
			elsif (/^(md[0-9]+)\s*:\s*([\S]+)(\s\([^)]+\))?\s(.*)/){
				$component_string = $4;
				$level = 'N/A';
			}
			@temp = ();
			# cascade of tests, light to cpu intense
			if ((!$maj_min || !$size) && @proc_partitions){
				$part = PartitionData::get($id);
				if (@$part){
					$maj_min = $part->[0] . ':' . $part->[1];
					$size = $part->[2];
				}
			}
			if ((!$maj_min || !$size) && @lsblk){
				$device = LsblkData::get($id) if @lsblk;
				$maj_min = $device->{'maj-min'} if $device->{'maj-min'};
				$size = $device->{'size'} if $device->{'size'};
			}
			if ((!$size || $b_admin) && $alerts{'mdadm'}->{'action'} eq 'use'){
				$details = md_details($id);
				$size = $details->{'size'} if $details->{'size'};
			}
			$raw_logical[0] += $size if $size;
			# remember, these include the [x] id, so remove that for disk/unmounted
			foreach my $component (split(/\s+/, $component_string)){
				my (%data,$maj_min,$name,$number,$info,$mapped,$part_size,$state);
				if ($component =~ /([\S]+)\[([0-9]+)\]\(?([SF])?\)?/){
					($name,$number,$info) = ($1,$2,$3);
				}
				elsif ($component =~ /([\S]+)/){
					$name = $1;
				}
				next if !$name;
				if ($details->{'devices'} && ref $details->{'devices'} eq 'HASH'){
					$maj_min = $details->{'devices'}{$name}{'maj-min'};
					$state = $details->{'devices'}{$name}{'state'};
				}
				if ((!$maj_min || !$part_size) && @proc_partitions){
					$part = PartitionData::get($name);
					if (@$part){
						$maj_min = $part->[0] . ':' . $part->[1] if !$maj_min;
						$part_size = $part->[2] if !$part_size;
					}
				}
				if ((!$maj_min || !$part_size) && @lsblk){
					%data= LsblkData::get($name);
					$maj_min = $data{'maj-min'} if !$maj_min;
					$part_size = $data{'size'}if !$part_size;
				}
				$mapped = $dmmapper{$name} if %dmmapper;
				$raw_logical[1] += $part_size if $part_size;
				$state = $info if !$state && $info;
				push(@components,[$name,$number,$info,$part_size,$maj_min,$state,$mapped]);
			}
			# print "$component_string\n";
			$j = scalar @mdraid;
			push(@mdraid, {
			'chunk-size' => $details->{'chunk-size'}, # if we got it, great, if not, further down
			'components' => \@components,
			'details' => $details,
			'id' => $id,
			'level' => $level,
			'maj-min' => $maj_min,
			'size' => $size,
			'status' => $status,
			'type' => 'mdraid',
			});
		}
		# print "$_\n";
		if ($_ =~ /^([0-9]+)\sblocks/){
			$mdraid[$j]->{'blocks'} = $1;
		}
		if ($_ =~ /super\s([0-9\.]+)\s/){
			$mdraid[$j]->{'super-block'} = $1;
		}
		if ($_ =~ /algorithm\s([0-9\.]+)\s/){
			$mdraid[$j]->{'algorithm'} = $1;
		}
		if ($_ =~ /\[([0-9]+\/[0-9]+)\]\s\[([U_]+)\]/){
			$mdraid[$j]->{'report'} = $1;
			$mdraid[$j]->{'u-data'} = $2;
		}
		if ($_ =~ /resync=([\S]+)/){
			$mdraid[$j]->{'resync'} = $1;
		}
		if ($_ =~ /([0-9]+[km])\schunk/i){
			$mdraid[$j]->{'chunk-size'} = $1;
		}
		if ($_ =~ /(\[[=]*>[\.]*\]).*(resync|recovery)\s*=\s*([0-9\.]+%)?(\s\(([0-9\/]+)\))?/){
			$mdraid[$j]->{'progress-bar'} = $1;
			$mdraid[$j]->{'recovery-percent'} = $3 if $3;
			$mdraid[$j]->{'sectors-recovered'} = $5 if $5;
		}
		if ($_ =~ /finish\s*=\s*([\S]+)\s+speed\s*=\s*([\S]+)/){
			$mdraid[$j]->{'recovery-finish'} = $1;
			$mdraid[$j]->{'recovery-speed'} = $2;
		}
		# print 'mdraid loop: ', Data::Dumper::Dumper \@mdraid;
	}
	if (@mdraid){
		$mdraid[0]->{'supported-levels'} = $system if $system;
		$mdraid[0]->{'unused'} = $unused if $unused;
	}
	print Data::Dumper::Dumper \@mdraid if $dbg[37];
	eval $end if $b_log;
	return @mdraid;
}

sub md_details {
	eval $start if $b_log;
	my ($id) = @_;
	my (@working);
	my $details = {};
	my $cmd = $alerts{'mdadm'}->{'path'} . " --detail /dev/$id 2>/dev/null";
	my @data = main::grabber($cmd,'','strip');
	main::log_data('dump',"$id raw: \@data",\@data) if $b_log;
	foreach (@data){
		@working = split(/\s*:\s*/, $_, 2);
		if (scalar @working == 2){
			if ($working[0] eq 'Array Size' && $working[1] =~ /^([0-9]+)\s\(/){
				$details->{'size'} = $1;
			}
			elsif ($working[0] eq 'Active Devices'){
				$details->{'c-active'} = $working[1];
			}
			elsif ($working[0] eq 'Chunk Size'){
				$details->{'chunk-size'} = $working[1];
			}
			elsif ($working[0] eq 'Failed Devices'){
				$details->{'c-failed'} = $working[1];
			}
			elsif ($working[0] eq 'Raid Devices'){
				$details->{'c-raid'} = $working[1];
			}
			elsif ($working[0] eq 'Spare Devices'){
				$details->{'c-spare'} = $working[1];
			}
			elsif ($working[0] eq 'State'){
				$details->{'state'} = $working[1];
			}
			elsif ($working[0] eq 'Total Devices'){
				$details->{'c-total'} = $working[1];
			}
			elsif ($working[0] eq 'Used Dev Size' && $working[1] =~ /^([0-9]+)\s\(/){
				$details->{'dev-size'} = $1;
			}
			elsif ($working[0] eq 'UUID'){
				$details->{'uuid'} = $working[1];
			}
			elsif ($working[0] eq 'Working Devices'){
				$details->{'c-working'} = $working[1];
			}
		}
		# end component data lines
		else {
			@working = split(/\s+/,$_);
			# 0       8       80        0      active sync   /dev/sdf
			# 2       8      128        -      spare   /dev/sdi
			next if !@working || $working[0] eq 'Number' || scalar @working < 6;
			$working[-1] =~ s|^/dev/(mapper/)?||;
			$details->{'devices'}{$working[-1]} = {
			'maj-min' => $working[1] . ':' . $working[2],
			'number' => $working[0],
			'raid-device' => $working[3],
			'state' => join(' ', @working[4..($#working - 1)]),
			};
		}
	}
	# print Data::Dumper::Dumper $details;
	main::log_data('dump',$id . ': %$details',$details) if $b_log;
	eval $end if $b_log;
	return $details;
}

sub soft_data {
	eval $start if $b_log;
	my ($cmd,$id,$state,$status,@data,@softraid,@working);
	# already been set in DiskDataBSD but we know the device exists
	foreach my $device (@{$sysctl{'softraid'}}){
		if ($device =~ /\.drive[\d]+:([\S]+)\s\(([a-z0-9]+)\)[,\s]+(\S+)/){
			my ($level,$size,@components);
			$id = $2;
			$status = $1;
			$state = $3;
			if ($alerts{'bioctl'}->{'action'} eq 'use'){
				$cmd = $alerts{'bioctl'}->{'path'} . " $id 2>/dev/null";
				@data = main::grabber($cmd,'','strip');
				main::log_data('dump','softraid @data',\@data) if $b_log;
				shift @data if @data; # get rid of headers 
				foreach my $row (@data){
					@working = split(/\s+/,$row);
					next if !defined $working[0];
					if ($working[0] =~ /^softraid/){
						if ($working[3] && main::is_numeric($working[3])){
							$size = $working[3]/1024;# it's in bytes
							$raw_logical[0] += $size;
						}
						$status = lc($working[2]) if $working[2];
						$state = lc(join(' ', @working[6..$#working])) if $working[6];
						$level = lc($working[5]) if $working[5];
					}
					elsif ($working[0] =~ /^[\d]{1,2}$/){
						my ($c_id,$c_device,$c_size,$c_status);
						if ($working[2] && main::is_numeric($working[2])){
							$c_size = $working[2]/1024;# it's in bytes
							$raw_logical[1] += $c_size;
						}
						$c_status = lc($working[1]) if $working[1];
						if ($working[3] && $working[3] =~ /^([\d:\.]+)$/){
							$c_device = $1;
						}
						if ($working[5] && $working[5] =~ /<([^>]+)>/){
							$c_id = $1;
						}
						# when offline, there will be no $c_id, but we want to show device
						if (!$c_id && $c_device){
							$c_id = $c_device;
						}
						push(@components,[$c_id,$c_size,$c_status,$c_device]) if $c_id;
					}
				}
			}
			push(@softraid, {
			'components' => \@components,
			'id' => $id,
			'level' => $level,
			'size' => $size,
			'state' => $state,
			'status' => $status,
			'type' => 'softraid',
			});
		}
	}
	print Data::Dumper::Dumper \@softraid if $dbg[37];
	main::log_data('dump','@softraid',\@softraid) if $b_log;
	eval $end if $b_log;
	return @softraid;
}

sub zfs_data {
	eval $start if $b_log;
	my ($zpool) = @_;
	my (@data,@zfs);
	my ($allocated,$free,$size,$size_holder,$status,$zfs_used,$zfs_avail,
	$zfs_size);
	my $b_v = 1;
	my ($i,$j,$k) = (0,0,0);
	if ($fake{'raid-zfs'}){
		 my $file;
		# $file = "$fake_data_dir/raid-logical/zfs/zpool-list-1-mirror-main-solestar.txt";
		# $file = "$fake_data_dir/raid-logical/zfs/zpool-list-2-mirror-main-solestar.txt";
		# $file = "$fake_data_dir/raid-logical/zfs/zpool-list-v-tank-1.txt";
		# $file = "$fake_data_dir/raid-logical/zfs/zpool-list-v-gojev-1.txt";
		# $file = "$fake_data_dir/raid-logical/zfs/zpool-list-v-w-spares-1.txt";
		 $file = "$fake_data_dir/raid-logical/zfs/zpool-list-v-freebsd-linear-1.txt";
		@data = main::reader($file);$zpool = '';
	}
	else {
		@data = main::grabber("$zpool list -v 2>/dev/null");
	}
	# bsd sed does not support inserting a true \n so use this trick
	# some zfs does not have -v
	if (!@data){
		@data = main::grabber("$zpool list 2>/dev/null");
		$b_v = 0;
	}
	my $zfs_path = main::check_program('zfs');
	# print 'zpool @data: ', Data::Dumper::Dumper \@data;
	main::log_data('dump','@data',\@data) if $b_log;
	if (!@data){
		main::log_data('data','no zpool list data') if $b_log;
		eval $end if $b_log;
		return ();
	}
	my ($status_i) = (0);
	# NAME   SIZE  ALLOC   FREE  EXPANDSZ   FRAG    CAP  DEDUP  HEALTH  ALTROOT
	my $test = shift @data; # get rid of first header line
	if ($test){
		foreach (split(/\s+/, $test)){
			last if $_ eq 'HEALTH';
			$status_i++;
		}
	}
	foreach (@data){
		my @row = split(/\s+/, $_);
		if (/^[\S]+/){
			$i = 0;
			$size = ($row[1] && $row[1] ne '-') ? main::translate_size($row[1]): '';
			$allocated = ($row[2] && $row[2] ne '-')? main::translate_size($row[2]): '';
			$free = ($row[3] && $row[3] ne '-')? main::translate_size($row[3]): '';
			($zfs_used,$zfs_avail) = zfs_fs_sizes($zfs_path,$row[0]) if $zfs_path;
			if (defined $zfs_used && defined $zfs_avail){
				$zfs_size = $zfs_used + $zfs_avail;
				$raw_logical[0] += $zfs_size; 
			}
			else {
				# must be BEFORE '$size_holder =' because only used if hits a new device
				# AND unassigned via raid/mirror arrays. Corner case for > 1 device systems. 
				$raw_logical[0] += $size_holder if $size_holder; 
				$size_holder = $size;
			}
			$status = (defined $row[$status_i] && $row[$status_i] ne '') ? $row[$status_i]: 'no-status';
			$j = scalar @zfs;
			push(@zfs, {
			'id' => $row[0],
			'arrays' => ([],),
			'raw-allocated' => $allocated,
			'raw-free' => $free,
			'raw-size' => $size,
			'zfs-free' => $zfs_avail,
			'zfs-size' => $zfs_size,
			'status' => $status,
			'type' => 'zfs',
			});
		}
		# print Data::Dumper::Dumper \@zfs;
		# raid level is the second item in the output, unless it is not, sometimes it is absent
		elsif ($row[1] =~ /raid|mirror/){
			$row[1] =~ s/^raid1/mirror/;
			#$row[1] =~ s/^raid/raid-/; # need to match in zpool status <device>
			$k = scalar @{$zfs[$j]->{'arrays'}};
			$zfs[$j]->{'arrays'}[$k]{'level'} = $row[1];
			$i = 0;
			$size = ($row[2] && $row[2] ne '-') ? main::translate_size($row[2]) : '';
			if (!defined $zfs_used || !defined $zfs_avail){
				$size_holder = 0;
				$raw_logical[0] += $size if $size;
			}
			$zfs[$j]->{'arrays'}[$k]{'raw-allocated'} = ($row[3] && $row[3] ne '-') ? main::translate_size($row[3]) : '';
			$zfs[$j]->{'arrays'}[$k]{'raw-free'} = ($row[4] && $row[4] ne '-') ? main::translate_size($row[4]) : '';
			$zfs[$j]->{'arrays'}[$k]{'raw-size'} = $size;
		}
		# https://blogs.oracle.com/eschrock/entry/zfs_hot_spares
		elsif ($row[1] =~ /spares?/){
			next;
		}
		# A member of a raid array:
		#  ada2        -      -      -         -      -      -
		# A single device not in an array:
		#  ada0s2    25.9G  14.6G  11.3G         -     0%    56%
		#    gptid/3838f796-5c46-11e6-a931-d05099ac4dc2      -      -      -         -      -      -
		# A single device not in an array:
		#  ada0p4      5G  3.88G   633M        -         -    49%  86.3%      -    ONLINE
		# Using /dev/disk/by-id:
		#  ata-VBOX_HARDDISK_VB5b6350cd-06618d58    
		# Using /dev/disk/by-partuuid:
		#  ec399377-c03c-e844-a876-8c8b044124b8     -        -         -      -      -      -  ONLINE
		# Spare in use:
		#  /home/fred/zvol/hdd-2-3          -      -      -        -         -      -      -      -  INUSE
		elsif ($row[1] =~ /^(sd[a-z]+|[a-z0-9]+[0-9]+|([\S]+)\/.*|(ata|mmc|nvme|pci|scsi|wwn)-\S+|[a-f0-9]{4,}(-[a-f0-9]{4,}){3,})$/ && 
		($row[2] eq '-' || $row[2] =~ /^[0-9\.]+[MGTPE]$/)){
			shift @row if !$row[0]; # get rid of empty first column
			# print Data::Dumper::Dumper \@row;
			# print 'status-i: ', $row[$status_i], ' row0: ', $row[0], "\n";
			my ($maj_min,$real,$part_size,$state,$working);
			#print "r1:$row[1]",' :: ', Cwd::abs_path('/dev/disk/by-id/'.$row[1]), "\n";
			if ($row[0] =~ /^(sd[a-z]+|[a-z0-9]+[0-9]+|([\S]+)\/.*|(ata|mmc|nvme|pci|scsi|wwn)-\S+|[a-f0-9]{4,}(-[a-f0-9]{4,}){3,})$/){
				$working = $1; # note: the negative case can never happen
			}
			# We only care about non ONLINE states for components
			if ($status_i && $row[$status_i] &&
			$row[$status_i] =~ /^(DEGRADED|FAULTED|INUSE|OFFLINE)$/){
				$state = $1;
			}
			if ($bsd_type){
				if ($working =~ /[\S]+\//){
					my $temp = GlabelData::get($working);
					$working = $temp if $temp;
				}
			}
			elsif (!$bsd_type){
				if ($row[0] =~ /^(ata|mmc|nvme|scsi|wwn)-/ && 
				-e "/dev/disk/by-id/$row[0]" && ($real = Cwd::abs_path('/dev/disk/by-id/'.$row[0]))){
					$real =~ s|/dev/||;
					$working = $real;
				}
				elsif ($row[0] =~ /^(pci)-/ && 
				-e "/dev/disk/by-path/$row[0]" && ($real = Cwd::abs_path('/dev/disk/by-path/'.$row[0]))){
					$real =~ s|/dev/||;
					$working = $real;
				}
				elsif ($row[0] =~ /^[a-f0-9]{4,}(-[a-f0-9]{4,}){3,}$/ &&
				-e "/dev/disk/by-partuuid/$row[0]" && ($real = Cwd::abs_path('/dev/disk/by-partuuid/'.$row[0]))){
					$real =~ s|/dev/||;
					$working = $real;
				}
			}
			# kind of a hack, things like cache may not show size/free
			# data since they have no array row, but they might show it in 
			# component row:
			#   ada0s2    25.9G  19.6G  6.25G         -     0%    75%
			#   ec399377-c03c-e844-a876-8c8b044124b8  1.88G   397M  1.49G        -         -     0%  20.7%      -    ONLINE
			# keys were size/allocated/free but those keys don't exist, assume failed to add raw-
			if (!$zfs[$j]->{'raw-size'} && $row[1] && $row[1] ne '-'){
				$size = ($row[1]) ? main::translate_size($row[1]): '';
				$size_holder = 0;
				$zfs[$j]->{'arrays'}[$k]{'raw-size'} = $size;
				$raw_logical[0] += $size if $size;
			}
			if (!$zfs[$j]->{'raw-allocated'} && $row[2] && $row[2] ne '-'){
				$allocated = ($row[2]) ? main::translate_size($row[2]) : '';
				$zfs[$j]->{'arrays'}[$k]{'raw-allocated'} = $allocated;
			}
			if (!$zfs[$j]->{'raw-free'} && $row[3] && $row[3] ne '-'){
				$free = ($row[3]) ? main::translate_size($row[3]) : '';
				$zfs[$j]->{'arrays'}[$k]{'raw-free'} = $free;
			}
			if ((!$maj_min || !$part_size) && $working && @proc_partitions){
				my $part = PartitionData::get($working);
				if (@$part){
					$maj_min = $part->[0] . ':' . $part->[1];
					$part_size = $part->[2];
				}
			}
			if ((!$maj_min || !$part_size) && $working && @lsblk){
				my $data= LsblkData::get($working);
				$maj_min = $data->{'maj-min'};
				$part_size = $data->{'size'};
			}
			if (!$part_size && $bsd_type && $working){
				my $temp = DiskDataBSD::get($working);
				$part_size = $temp->{'size'} if $temp->{'size'};
			}
			# with linear zfs, can show full partition size data
			if (!$part_size && $working && $row[1] && $row[1] ne '-'){
				$part_size = main::translate_size($row[1]);
			}
			$raw_logical[1] += $part_size if $part_size;
			$zfs[$j]->{'arrays'}[$k]{'components'}[$i] = [$working,$part_size,$maj_min,$state];
			$i++;
		}
	}
	$raw_logical[0] += $size_holder if $size_holder;
	# print Data::Dumper::Dumper \@zfs;
	# clear out undefined arrrays values
	$j = 0;
	foreach my $row (@zfs){
		my @arrays = (ref $row->{'arrays'} eq 'ARRAY') ? @{$row->{'arrays'}} : ();
		@arrays = grep {defined $_} @arrays;
		$zfs[$j]->{'arrays'} = \@arrays;
		$j++;
	}
	@zfs = zfs_status($zpool,\@zfs);
	print Data::Dumper::Dumper \@zfs if $dbg[37];
	eval $end if $b_log;
	return @zfs;
}

sub zfs_fs_sizes {
	my ($path,$id) = @_;
	eval $start if $b_log;
	my @data;
	my @result = main::grabber("$path list -pH $id 2>/dev/null",'','strip');
	main::log_data('dump','zfs list @result',\@result) if $b_log;
	print Data::Dumper::Dumper \@result if $dbg[37];
	# some zfs devices do not have zfs data, lake spare storage devices
	if (@result){
		my @working = split(/\s+/,$result[0]);
		$data[0] = $working[1]/1024 if $working[1];
		$data[1] = $working[2]/1024 if $working[2];
	}
	elsif ($b_log || $dbg[37]) {
		@result = main::grabber("$path list -pH $id 2>&1",'','strip');
		main::log_data('dump','zfs list w/error @result',\@result) if $b_log;
		print '@result w/error: ', Data::Dumper::Dumper \@result if $dbg[37];
	}
	eval $end if $b_log;
	return @data;
}

sub zfs_status {
	eval $start if $b_log;
	my ($zpool,$zfs) = @_;
	my ($cmd,$level,$status,@pool_status,@temp);
	my ($i,$j,$k,$l) = (0,0,0,0);
	foreach my $row (@$zfs){
		$i = 0;
		$k = 0;
		if ($fake{'raid-zfs'}){
			my $file;
			# $file = "$fake_data_dir/raid-logical/zfs/zpool-status-1-mirror-main-solestar.txt";
			# $file = "$fake_data_dir/raid-logical/zfs/zpool-status-2-mirror-main-solestar.txt";
			# $file = "$fake_data_dir/raid-logical/zfs/zpool-status-tank-1.txt";
			#@pool_status = main::reader($file,'strip');
		}
		else {
			$cmd = "$zpool status $row->{'id'} 2>/dev/null";
			@pool_status = main::grabber($cmd,"\n",'strip');
		}
		main::log_data('cmd',$cmd) if $b_log;
		# @arrays = (ref $row->{'arrays'} eq 'ARRAY') ? @{$row->{'arrays'}} : ();
		# print "$row->{'id'} rs:$row->{'status'}\n";
		$status = ($row->{'status'} && $row->{'status'} eq 'no-status') ? check_zfs_status($row->{'id'},\@pool_status): $row->{'status'};
		$zfs->[$j]{'status'} = $status if $status;
		#@arrays = grep {defined $_} @arrays;
		# print "$row->{id} $#arrays\n";
		# print Data::Dumper::Dumper \@arrays;
		foreach my $array (@{$row->{'arrays'}}){
			# print 'ref: ', ref $array, "\n";
			#next if ref $array ne 'HASH';
			my @components = (ref $array->{'components'} eq 'ARRAY') ? @{$array->{'components'}} : ();
			$l = 0;
			# zpool status: mirror-0  ONLINE       2     0     0
			$level = ($array->{'level'}) ? "$array->{'level'}-$i": $array->{'level'};
			$status = ($level) ? check_zfs_status($level,\@pool_status): '';
			$zfs->[$j]{'arrays'}[$k]{'status'} = $status;
			# print "$level i:$i j:$j k:$k $status\n";
			foreach my $component (@components){
				my @temp = split('~', $component);
				$status = ($temp[0]) ? check_zfs_status($temp[0],\@pool_status): '';
				$zfs->[$j]{'arrays'}[$k]{'components'}[$l] .= $status if $status;
				$l++;
			}
			$k++;
			# haven't seen a raid5/6 type array yet, zfs uses z1,z2,and z3
			$i++ if $array->{'level'}; # && $array->{'level'} eq 'mirror';
		}
		$j++;
	}
	eval $end if $b_log;
	return @$zfs;
}

sub check_zfs_status {
	eval $start if $b_log;
	my ($item,$pool_status) = @_;
	my ($status) = ('');
	foreach (@$pool_status){
		my @temp = split(/\s+/, $_);
		if ($temp[0] eq $item){
			last if !$temp[1]; 
			$status = $temp[1];
			last;
		}
	}
	eval $end if $b_log;
	return $status;
}
}

## RamItem
{