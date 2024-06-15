package LogicalItem;

sub get {
	eval $start if $b_log;
	my ($key1,$val1);
	my $rows = [];
	my $num = 0;
	if ($bsd_type){
		$key1 = 'Message';
		$val1 = main::message('logical-data-bsd',$uname[0]);
		push(@$rows,{main::key($num++,0,1,$key1) => $val1});
	}
 	else {
		LsblkData::set() if !$loaded{'lsblk'};
		if ($fake{'logical'} || $alerts{'lvs'}->{'action'} eq 'use'){
			lvm_data() if !$loaded{'logical-data'};
			if (!@lvm){
				my $key = 'Message';
				# note: arch linux has a bug where lvs returns 0 if non root start
				my $message = ($use{'logical-lvm'}) ? main::message('tool-permissions','lvs') : main::message('logical-data','');
				push(@$rows, {
				main::key($num++,0,1,$key) => $message,
				});
			}
			else {
				lvm_output($rows,process_lvm_data());
			}
		}
		elsif ($use{'logical-lvm'} && $alerts{'lvs'}->{'action'} eq 'permissions'){
			my $key = 'Message';
			push(@$rows, {
			main::key($num++,0,1,$key) => $alerts{'lvs'}->{'message'},
			});
		}
		elsif (@lsblk && !$use{'logical-lvm'} && ($alerts{'lvs'}->{'action'} eq 'permissions' || 
		$alerts{'lvs'}->{'action'} eq 'missing')){
			my $key = 'Message';
			push(@$rows, {
			main::key($num++,0,1,$key) => main::message('logical-data',''),
			});
		}
		elsif ($alerts{'lvs'}->{'action'} ne 'use'){
			$key1 = $alerts{'lvs'}->{'action'};
			$val1 = $alerts{'lvs'}->{'message'};
			$key1 = ucfirst($key1);
			push(@$rows, {main::key($num++,0,1,$key1) => $val1});
		}
		if ($use{'logical-general'}){
			my $general_data = general_data();
			general_output($rows,$general_data) if @$general_data;
		}
	}
	eval $end if $b_log;
	return $rows;
}

sub general_output {
	eval $start if $b_log;
	my ($rows,$general_data) = @_;
	my ($size);
	my ($j,$num) = (0,0);
	# cryptsetup status luks-a00baac5-44ff-4b48-b303-3bedb1f623ce
	foreach my $item (sort {$a->{'type'} cmp $b->{'type'}} @$general_data){
		$j = scalar @$rows;
		$size = ($item->{'size'}) ? main::get_size($item->{'size'}, 'string') : 'N/A';
		push(@$rows,{
		main::key($num++,1,1,'Device') => $item->{'name'},
		});
		if ($b_admin){
			$item->{'name'} ||= 'N/A';
			$rows->[$j]{main::key($num++,0,2,'maj-min')} = $item->{'maj-min'};
		}
		$rows->[$j]{main::key($num++,0,2,'type')} = $item->{'type'};
		if ($extra > 0 && $item->{'dm'}){
			$rows->[$j]{main::key($num++,0,2,'dm')} = $item->{'dm'};
		}
		$rows->[$j]{main::key($num++,0,2,'size')} = $size;
		my $b_fake;
		components_output('general',\$j,\$num,$rows,\@{$item->{'components'}},\$b_fake);
	}
	eval $end if $b_log;
}

sub lvm_output {
	eval $start if $b_log;
	my ($rows,$lvm_data) = @_;
	my ($size);
	my ($j,$num) = (0,0);
	foreach my $vg (sort keys %$lvm_data){
		$j = scalar @$rows;
		# print Data::Dumper::Dumper $lvm_data->{$vg};
		$size = main::get_size($lvm_data->{$vg}{'vg-size'},'string','N/A');
		push(@$rows,{
		main::key($num++,1,1,'Device') => '',
		main::key($num++,0,2,'VG') => $vg,
		main::key($num++,0,2,'type') => uc($lvm_data->{$vg}{'vg-format'}),
		main::key($num++,0,2,'size') => $size,
		},);
		$size = main::get_size($lvm_data->{$vg}{'vg-free'},'string','N/A');
		$rows->[$j]{main::key($num++,0,2,'free')} = $size;
		foreach my $lv (sort keys %{$lvm_data->{$vg}{'lvs'}}){
			next if $extra < 2 && $lv =~ /^\[/; # it's an internal vg lv, raid meta/image 
			$j = scalar @$rows;
			my $b_raid;
			$size = main::get_size($lvm_data->{$vg}{'lvs'}{$lv}{'lv-size'},'string','N/A');
			$rows->[$j]{main::key($num++,1,2,'LV')} = $lv;
			if ($b_admin && $lvm_data->{$vg}{'lvs'}{$lv}{'maj-min'}){
				$rows->[$j]{main::key($num++,0,3,'maj-min')} = $lvm_data->{$vg}{'lvs'}{$lv}{'maj-min'};
			}
			$rows->[$j]{main::key($num++,0,3,'type')} = $lvm_data->{$vg}{'lvs'}{$lv}{'lv-type'};
			if ($extra > 0 && $lvm_data->{$vg}{'lvs'}{$lv}{'dm'}){
				$rows->[$j]{main::key($num++,0,3,'dm')} = $lvm_data->{$vg}{'lvs'}{$lv}{'dm'};
			}
			$rows->[$j]{main::key($num++,0,3,'size')} = $size;
			if ($extra > 1 && !($show{'raid'} || $show{'raid-basic'}) && $lvm_data->{$vg}{'lvs'}{$lv}{'raid'}){
				$j = scalar @$rows;
				$rows->[$j]{main::key($num++,1,3,'RAID')} = '';
				$rows->[$j]{main::key($num++,0,4,'stripes')} = $lvm_data->{$vg}{'lvs'}{$lv}{'raid'}{'stripes'};
				$rows->[$j]{main::key($num++,0,4,'sync')} = $lvm_data->{$vg}{'lvs'}{$lv}{'raid'}{'sync'};
				my $copied = $lvm_data->{$vg}{'lvs'}{$lv}{'raid'}{'copied'};
				$copied = (defined $copied) ? ($copied + 0) . '%': 'N/A';
				$rows->[$j]{main::key($num++,0,4,'copied')} = $copied;
				$rows->[$j]{main::key($num++,0,4,'mismatches')} = $lvm_data->{$vg}{'lvs'}{$lv}{'raid'}{'mismatches'};
				$b_raid = 1;
			}
			components_output('lvm',\$j,\$num,$rows,\@{$lvm_data->{$vg}{'lvs'}{$lv}{'components'}},\$b_raid);
		}
	}
	eval $end if $b_log;
}

sub components_output {
	my ($type,$j,$num,$rows,$components,$b_raid) = @_;
	my ($l1);
	$$j = scalar @$rows if $$b_raid || $extra > 1;
	$$b_raid = 0;
	if ($type eq 'general'){
		($l1) = (2);
	}
	elsif ($type eq 'lvm'){
		($l1) = (3);
	}
	my $status = (!@$components) ? 'N/A': '';
	$rows->[$$j]{main::key($$num++,1,$l1,'Components')} = $status;
	components_recursive_output($type,$j,$num,$rows,$components,0,'c','p');
}

sub components_recursive_output {
	my ($type,$j,$num,$rows,$components,$indent,$c,$p) = @_;
	my ($l,$m,$size) = (1,1,0);
	my ($l2,$l3);
	if ($type eq 'general'){
		($l2,$l3) = (3+$indent,4+$indent) ;
	}
	elsif ($type eq 'lvm'){
		($l2,$l3) = (4+$indent,5+$indent);
	}
	# print 'outside: ', scalar @$component, "\n", Data::Dumper::Dumper $component;
	foreach my $component (@$components){
		# print "inside: -n", Data::Dumper::Dumper $component->[$i];
		$$j = scalar @$rows if $b_admin;
		my $id;
		if ($component->[0] =~ /^(bcache|dm-|md)[0-9]/){
			$id = $c .'-' . $m;
			$m++;
		}
		else {
			$id = $p . '-' . $l;
			$l++;
		}
		$rows->[$$j]{main::key($$num++,1,$l2,$id)} = $component->[0];
		if ($extra > 1){
			if ($b_admin){
				$component->[1] ||= 'N/A';
				$rows->[$$j]{main::key($$num++,0,$l3,'maj-min')} = $component->[1];
				$rows->[$$j]{main::key($$num++,0,$l3,'mapped')} = $component->[3] if $component->[3];
				$size = main::get_size($component->[2],'string','N/A');
				$rows->[$$j]{main::key($$num++,0,$l3,'size')} = $size;
			}
			#next if !$component->[$i][4];
			for (my $i = 4; $i < scalar @$component; $i++){
				components_recursive_output($type,$j,$num,$rows,$component->[$i],$indent+1,$c.'c',$p.'p');
			}
		}
	}
}

# Note: type dm is seen in only one dataset, but it's a start
sub general_data {
	eval $start if $b_log;
	my (@found,$parent,$parent_fs);
	my $general_data = [];
	PartitionData::set('proc') if !$loaded{'partition-data'};
	main::set_mapper() if !$loaded{'mapper'};
	foreach my $row (@lsblk){
		# bcache doesn't have mapped name: !$mapper{$row->{'name'}} || 
		next if !$row->{'parent'};
		$parent = LsblkData::get($row->{'parent'});
		next if !$parent->{'fs'};
		if ($row->{'type'} && (($row->{'type'} eq 'crypt' || 
		$row->{'type'} eq 'mpath' || $row->{'type'} eq 'multipath')  ||
		($row->{'type'} eq 'dm' && $row->{'name'} =~ /veracrypt/i) ||
		($parent->{'fs'} eq 'bcache'))){
			my (@full_components,$mapped,$type);
			$mapped = $mapper{$row->{'name'}} if %mapper;
			next if grep(/^$row->{'name'}$/, @found);
			push(@found,$row->{'name'});
			if ($parent->{'fs'} eq 'crypto_LUKS'){
				$type = 'LUKS';
			}
			# note, testing name is random user string, and there is no other
			# ID known, the parent FS is '', empty.
			elsif ($row->{'type'} eq 'dm' && $row->{'name'} =~ /veracrypt/i){
				$type = 'VeraCrypt';
			}
			elsif ($row->{'type'} eq 'crypt'){
				$type = 'Crypto';
			}
			elsif ($parent->{'fs'} eq 'bcache'){
				$type = 'bcache';
			}
			# probably only seen on older Redhat servers, LVM probably replaces
			elsif ($row->{'type'} eq 'mpath' || $row->{'type'} eq 'multipath'){
				$type = 'MultiPath';
			}
			elsif ($row->{'type'} eq 'crypt'){
				$type = 'Crypt';
			}
			# my $name = ($use{'filter-uuid'}) ? "luks-$filter_string" : $row->{'name'};
			component_data($row->{'maj-min'},\@full_components);
			# print "$row->{'name'}\n", Data::Dumper::Dumper \@full_components;
			push(@$general_data, {
			'components' => \@full_components,
			'dm' => $mapped,
			'maj-min' => $row->{'maj-min'},
			'name' => $row->{'name'},
			'size' => $row->{'size'},
			'type' => $type,
			});
		}
	}
	main::log_data('dump','luks @$general_data', $general_data);
	print Data::Dumper::Dumper $general_data if $dbg[23];
	eval $end if $b_log;
	return $general_data;
}

# Note: called for disk totals, raid, and logical
sub lvm_data {
	eval $start if $b_log;
	$loaded{'logical-data'} = 1;
	my (@args,@data,%totals);
	@args = qw(vg_name vg_fmt vg_size vg_free lv_name lv_layout lv_size 
	lv_kernel_major lv_kernel_minor segtype seg_count seg_start_pe seg_size_pe 
	stripes devices raid_mismatch_count raid_sync_action raid_write_behind
	copy_percent);
	my $num = 0;
	PartitionData::set() if !$loaded{'partition-data'};
	main::set_mapper() if !$loaded{'mapper'};
	if ($fake{'logical'}){
		# my $file = "$fake_data_dir/raid-logical/lvm/lvs-test-1.txt";
		# @data = main::reader($file,'strip');
	}
	else {
		# lv_full_name: ar0-home; lv_dm_path: /dev/mapper/ar0-home
		# seg_size: unit location on volume where segement starts
		#   2>/dev/null -unit k  ---separator ^:
		my $cmd = $alerts{'lvs'}->{'path'};
		$cmd .= ' -aPv --unit k --separator "^:" --segments --noheadings -o ';
		# $cmd .= ' -o +lv_size,pv_major,pv_minor 2>/dev/null';
		$cmd .= join(',', @args) . ' 2>/dev/null';
		@data = main::grabber($cmd,'','strip');
		main::log_data('dump','lvm @data', \@data) if $b_log;
		print "command: $cmd\n" if $dbg[22];
	}
	my $j = 0;
	foreach (@data){
		my @line = split(/\^:/, $_);
		next if $_ =~ /^Partial mode/i; # sometimes 2>/dev/null doesn't catch this
		for (my $i = 0; $i < scalar @args; $i++){
			$line[$i] =~ s/k$// if $args[$i] =~ /_(free|size|used)$/;
			$lvm[$j]->{$args[$i]} = $line[$i];
		}
		if (!$totals{'vgs'}->{$lvm[$j]->{'vg_name'}}){
			$totals{'vgs'}->{$lvm[$j]->{'vg_name'}} = $lvm[$j]->{'vg_size'};
			$raw_logical[2] += $lvm[$j]->{'vg_free'} if $lvm[$j]->{'vg_free'};
		}
		$j++;
	}
	# print Data::Dumper::Dumper \%totals, \@raw_logical;
	main::log_data('dump','lvm @lvm', \@lvm) if $b_log;
	print Data::Dumper::Dumper \@lvm if $dbg[22];
	eval $end if $b_log;
}

sub process_lvm_data {
	eval $start if $b_log;
	my $processed = {};
	foreach my $item (@lvm){
		my (@components,@devices,$dm,$dm_tmp,$dm_mm,@full_components,$maj_min,%raid,@temp);
		if (!$processed->{$item->{'vg_name'}}){
			$processed->{$item->{'vg_name'}}->{'vg-size'} = $item->{'vg_size'};
			$processed->{$item->{'vg_name'}}->{'vg-free'} = $item->{'vg_free'};
			$processed->{$item->{'vg_name'}}->{'vg-format'} = $item->{'vg_fmt'};
		}
		if (!$processed->{$item->{'vg_name'}}->{'lvs'}{$item->{'lv_name'}}){
			$processed->{$item->{'vg_name'}}->{'lvs'}{$item->{'lv_name'}}{'lv-size'} = $item->{'lv_size'};
			$processed->{$item->{'vg_name'}}->{'lvs'}{$item->{'lv_name'}}{'lv-type'} = $item->{'segtype'};
			$maj_min = $item->{'lv_kernel_major'} . ':' . $item->{'lv_kernel_minor'};
			$processed->{$item->{'vg_name'}}->{'lvs'}{$item->{'lv_name'}}{'maj-min'} = $maj_min;
			$dm_tmp = $item->{'vg_name'} . '-' . $item->{'lv_name'};
			$dm_tmp =~ s/\[|\]$//g;
			$dm = $mapper{$dm_tmp} if %mapper;
			$processed->{$item->{'vg_name'}}->{'lvs'}{$item->{'lv_name'}}{'dm'} = $dm;
			if ($item->{'segtype'} && $item->{'segtype'} ne 'linear' && $item->{'segtype'} =~ /^raid/){
				$raid{'copied'} = $item->{'copy_percent'};
				$raid{'mismatches'} = $item->{'raid_mismatch_count'};
				$raid{'stripes'} = $item->{'stripes'};
				$raid{'sync'} = $item->{'raid_sync_action'};
				$raid{'type'} = $item->{'segtype'};
				$processed->{$item->{'vg_name'}}->{'lvs'}{$item->{'lv_name'}}{'raid'} = \%raid;
			}
			component_data($maj_min,\@full_components);
			# print "$item->{'lv_name'}\n", Data::Dumper::Dumper \@full_components;
			$processed->{$item->{'vg_name'}}->{'lvs'}{$item->{'lv_name'}}{'components'} = \@full_components;
		}
	}
	main::log_data('dump','lvm %$processed', $processed) if $b_log;
	print Data::Dumper::Dumper $processed if $dbg[23];
	eval $end if $b_log;
	return $processed;
}

sub component_data {
	my ($maj_min,$full_components) = @_;
	push(@$full_components, component_recursive_data($maj_min));
}

sub component_recursive_data {
	eval $start if $b_log;
	my ($maj_min) = @_;
	my (@components,@devices);
	@devices = main::globber("/sys/dev/block/$maj_min/slaves/*") if -e "/sys/dev/block/$maj_min/slaves";
	@devices = map {$_ =~ s|^/.*/||; $_;} @devices if @devices;
	# return @devices if !$b_admin;
	foreach my $device (@devices){
		my ($mapped,$mm2,$part);
		$part = PartitionData::get($device) if @proc_partitions; 
		$mm2 = $part->[0] . ':' . $part->[1] if @$part;
		if ($device =~ /^(bcache|dm-|md)[0-9]+$/){
			$mapped = $dmmapper{$device};
			$raw_logical[1] += $part->[2] if $mapped && $mapped =~ /_(cdata|cmeta)$/;
			push(@components, [$device,$mm2,$part->[2],$mapped,[component_recursive_data($mm2)]]);
		}
		else {
			push(@components,[$device,$mm2,$part->[2]]);
		}
	}
	eval $end if $b_log;
	return @components;
}
}

## MachineItem
# public methods: get(), is_vm()
{
my $b_vm;