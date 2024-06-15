package UnmountedItem;

sub get {
	eval $start if $b_log;
	my ($data,$key1,$val1);
	my $rows = [];
	my $num = 0;
	if ($bsd_type){
		DiskDataBSD::set() if !$loaded{'disk-data-bsd'};
		if (%disks_bsd && ($alerts{'disklabel'}->{'action'} eq 'use' ||
		 $alerts{'gpart'}->{'action'} eq 'use')){
			$data = bsd_data();
			if (!@$data){
				$key1 = 'Message';
				$val1 = main::message('unmounted-data');
			}
			else {
				create_output($rows,$data);
			}
		}
		else {
			if ($alerts{'disklabel'}->{'action'} eq 'permissions'){
				$key1 = 'Message';
				$val1 = $alerts{'disklabel'}->{'message'};
			}
			else {
				$key1 = 'Message';
				$val1 = main::message('unmounted-data-bsd',$uname[0]);
			}
		}
	}
 	else {
		if ($system_files{'proc-partitions'}){
			$data = proc_data();
			if (!@$data){
				$key1 = 'Message';
				$val1 = main::message('unmounted-data');
			}
			else {
				create_output($rows,$data);
			}
		}
		else {
			$key1 = 'Message';
			$val1 = main::message('unmounted-file');
		}
 	}
 	if (!@$rows && $key1){
		@$rows = ({main::key($num++,0,1,$key1) => $val1});
 	}
	eval $end if $b_log;
	return $rows;
}

sub create_output {
	eval $start if $b_log;
	my ($rows,$unmounted) = @_;
	my ($fs);
	my ($j,$num) = (0,0);
	@$unmounted = sort { $a->{'dev-base'} cmp $b->{'dev-base'} } @$unmounted;
	my $fs_skip = PartitionItem::get_filters('fs-skip');
	foreach my $row (@$unmounted){
		$num = 1;
		my $size = ($row->{'size'}) ? main::get_size($row->{'size'},'string') : 'N/A';
		if ($row->{'fs'}){
			$fs = lc($row->{'fs'});
		}
		else {
			if ($bsd_type){
				$fs = 'N/A';
			}
			elsif (main::check_program('file')){
				$fs = ($b_root) ? 'N/A' : main::message('root-required');
			}
			else {
				$fs = main::message('tool-missing-basic','file');
			}
		}
		$j = scalar @$rows;
		push(@$rows, {
		main::key($num++,1,1,'ID') => "/dev/$row->{'dev-base'}",
		});
		if ($b_admin && $row->{'maj-min'}){
			$rows->[$j]{main::key($num++,0,2,'maj-min')} = $row->{'maj-min'};
		}
		if ($extra > 0 && $row->{'dev-mapped'}){
			$rows->[$j]{main::key($num++,0,2,'mapped')} = $row->{'dev-mapped'};
		}
		$row->{'label'} ||= 'N/A';
		$row->{'uuid'} ||= 'N/A';
		$rows->[$j]{main::key($num++,0,2,'size')} = $size;
		$rows->[$j]{main::key($num++,0,2,'fs')} = $fs;
		# don't show for fs known to not have label/uuid
		if (($show{'label'} || $show{'uuid'}) && $fs !~ /^$fs_skip$/){
			if ($show{'label'}){
				if ($use{'filter-label'}){
					$row->{'label'} = main::filter_partition('part', $row->{'label'}, '');
				}
				$row->{'label'} ||= 'N/A';
				$rows->[$j]{main::key($num++,0,2,'label')} = $row->{'label'};
			}
			if ($show{'uuid'}){
				if ($use{'filter-uuid'}){
					$row->{'uuid'} = main::filter_partition('part', $row->{'uuid'}, '');
				}
				$row->{'uuid'} ||= 'N/A';
				$rows->[$j]{main::key($num++,0,2,'uuid')} = $row->{'uuid'};
			}
		}
	}
	eval $end if $b_log;
}

sub proc_data {
	eval $start if $b_log;
	my ($dev_mapped,$fs,$label,$maj_min,$size,$uuid,$part);
	my $unmounted = [];
	# last filters to make sure these are dumped
	my @filters = ('scd[0-9]+','sr[0-9]+','cdrom[0-9]*','cdrw[0-9]*',
	'dvd[0-9]*','dvdrw[0-9]*','fd[0-9]','ram[0-9]*');
	my $num = 0;
	# set labels, uuid, gpart
	PartitionItem::set_partitions() if !$loaded{'set-partitions'};
	RaidItem::raid_data() if !$loaded{'raid'};
	my $mounted = get_mounted();
	# NOTE: add push(@$mounted,'data') here to emulate item, match partition data
	# print join("\n",(@filters,@$mounted)),"\n";
	foreach my $row (@proc_partitions){
		($dev_mapped,$fs,$label,$maj_min,$uuid,$size) = ('','','','','','');
		# note that size 1 means it is a logical extended partition container
		# lvm might have dm-1 type syntax
		# need to exclude loop type file systems, squashfs for example
		# NOTE: nvme needs special treatment because the main device is: nvme0n1
		# note: $working[2] != 1 is wrong, it's not related
		# note: for zfs using /dev/sda no partitions, previous rule would have removed
		# the unmounted report because sdb was found in sdb1, but match of eg sdb1 and sdb12
		# makes this a problem, so using zfs_member test instead to filter out zfs members.
		# For zfs using entire disk, ie, sda, in that case, all partitions sda1 sda9 (8BiB) 
		# belong to zfs, and aren't unmmounted, so if sda and partition sda9,
		# remove from list. this only works for sdxx drives, but is better than no fix
		# This logic may also end up working for btrfs partitions, and maybe hammer?
		# In arm/android seen /dev/block/mmcblk0p12
		# @filters test separate since it contains regex list, @$mounted can contain
		# regex special characters like GDRIVE{6Cm8i}:
		# print "mount: $row->[-1]\n";
		if ($row->[-1] !~ /^(nvme[0-9]+n|mmcblk|mtdblk|mtdblock)[0-9]+$/ && 
		$row->[-1] =~ /[a-z][0-9]+$|dm-[0-9]+$/ && 
		$row->[-1] !~ /\bloop/ && 
		!(grep {$row->[-1] =~ /$_$/} @filters) && 
		!(grep {$row->[-1] =~ /\Q$_\E$/} @$mounted) && 
		!(grep {$_ =~ /(block\/)?$row->[-1]$/} @$mounted) &&
		!(grep {$_ =~ /^sd[a-z]+$/ && $row->[-1] =~ /^\Q$_\E[0-9]+/} @$mounted)){
			$dev_mapped = $dmmapper{$row->[-1]} if $dmmapper{$row->[-1]};
			if (@lsblk){
				my $id = ($dev_mapped) ? $dev_mapped: $row->[-1];
				$part = LsblkData::get($id);
				if (%$part){
					$fs = $part->{'fs'};
					$label = $part->{'label'};
					$maj_min = $part->{'maj-min'};
					$uuid = $part->{'uuid'};
					$size = $part->{'size'} if $part->{'size'} && !$row->[2];
				}
			}
			$size ||= $row->[2];
			$fs = unmounted_filesystem($row->[-1]) if !$fs;
			# seen: (zfs|lvm2|linux_raid)_member; crypto_luks
			# note: lvm, raid members are never mounted. luks member is never mounted.
			next if $fs && $fs =~ /(bcache|crypto|luks|_member)$/i; 
			# these components of lvm raid will show as partitions byt are reserved private lvm member
			# See man lvm for all current reserved private volume names
			next if $dev_mapped && $dev_mapped =~ /_([ctv]data|corig|[mr]image|mlog|[crt]meta|pmspare|pvmove|vorigin)(_[0-9]+)?$/;
			if (!$bsd_type){
				$label = PartitionItem::get_label("/dev/$row->[-1]") if !$label;
				$uuid = PartitionItem::get_uuid("/dev/$row->[-1]") if !$uuid;
			}
			else {
				my @temp = GpartData::get($row->[-1]);
				$label = $temp[1] if $temp[1];
				$uuid = $temp[2] if $temp[2];
			}
			$maj_min = "$row->[0]:$row->[1]" if !$maj_min;
			push(@$unmounted, {
			'dev-base' => $row->[-1],
			'dev-mapped' => $dev_mapped,
			'fs' => $fs,
			'label' => $label,
			'maj-min' => $maj_min,
			'size' => $size,
			'uuid' => $uuid,
			});
		}
	}
	print Data::Dumper::Dumper $unmounted if $dbg[35];
	main::log_data('dump','@$unmounted',$unmounted) if $b_log;
	eval $end if $b_log;
	return $unmounted;
}

sub bsd_data {
	eval $start if $b_log;
	my ($fs,$label,$size,$uuid,%part);
	my $unmounted = [];
	PartitionItem::set_partitions() if !$loaded{'set-partitions'};
	RaidItem::raid_data() if !$loaded{'raid'};
	my $mounted = get_mounted();
	foreach my $id (sort keys %disks_bsd){
		next if !$disks_bsd{$id}->{'partitions'};
		foreach my $part (sort keys %{$disks_bsd{$id}->{'partitions'}}){
			if (!(grep {$_ =~ /$part$/} @$mounted)){
				$fs = $disks_bsd{$id}->{'partitions'}{$part}{'fs'};
				next if $fs && $fs =~ /(raid|_member)$/i; 
				$label = $disks_bsd{$id}->{'partitions'}{$part}{'label'};
				$size = $disks_bsd{$id}->{'partitions'}{$part}{'size'};
				$uuid = $disks_bsd{$id}->{'partitions'}{$part}{'uuid'};
				# $fs = unmounted_filesystem($part) if !$fs;
				push(@$unmounted, {
				'dev-base' => $part,
				'dev-mapped' => '',
				'fs' => $fs,
				'label' => $label,
				'maj-min' => '',
				'size' => $size,
				'uuid' => $uuid,
				});
			}
		}
	}
	print Data::Dumper::Dumper $unmounted if $dbg[35];
	main::log_data('dump','@$unmounted',$unmounted) if $b_log;
	eval $end if $b_log;
	return $unmounted;
}

sub get_mounted {
	eval $start if $b_log;
	my (@arrays);
	my $mounted = [];
	foreach my $row (@partitions){
		push(@$mounted, $row->{'dev-base'}) if $row->{'dev-base'};
	}
	# print Data::Dumper::Dumper \@zfs_raid;
	foreach my $row ((@btrfs_raid,@lvm_raid,@md_raid,@soft_raid,@zfs_raid)){
		# we want to not show md0 etc in unmounted report
		push(@$mounted, $row->{'id'}) if $row->{'id'}; 
		# print Data::Dumper::Dumper $row;
		# row->arrays->components: zfs; row->components: lvm,mdraid,softraid
		if ($row->{'arrays'} && ref $row->{'arrays'} eq 'ARRAY'){
			push(@arrays,@{$row->{'arrays'}});
		}
		elsif ($row->{'components'} && ref $row->{'components'} eq 'ARRAY'){
			push(@arrays,$row);
		}
		@arrays = grep {defined $_} @arrays;
		# print Data::Dumper::Dumper \@arrays;
		foreach my $item (@arrays){
			# print Data::Dumper::Dumper $item;
			my @components = (ref $item->{'components'} eq 'ARRAY') ? @{$item->{'components'}} : ();
			foreach my $component (@components){
				# md has ~, not zfs,lvm,softraid
				my $temp = (split('~', $component->[0]))[0]; 
				push(@$mounted, $temp);
			}
		}
	}
	eval $end if $b_log;
	return $mounted;
}

# bsds do not seem to return any useful data so only for linux
sub unmounted_filesystem {
	eval $start if $b_log;
	my ($item) = @_;
	my ($data,%part);
	my ($file,$fs,$path) = ('','','');
	if ($path = main::check_program('file')){
		$file = $path;
	}
	# order matters in this test!
	my @filesystems = ('ext2','ext3','ext4','ext5','ext','ntfs',
	'fat32','fat16','FAT\s\(.*\)','vfat','fatx','tfat','exfat','swap','btrfs',
	'ffs','hammer','hfs\+','hfs\splus','hfs\sextended\sversion\s[1-9]','hfsj',
	'hfs','apfs','jfs','nss','reiserfs','reiser4','ufs2','ufs','xfs','zfs');
	if ($file){
		# this will fail if regular user and no sudo present, but that's fine, it will just return null
		# note the hack that simply slices out the first line if > 1 items found in string
		# also, if grub/lilo is on partition boot sector, no file system data is available
		$data = (main::grabber("$sudoas$file -s /dev/$item 2>/dev/null"))[0];
		if ($data){
			foreach (@filesystems){
				if ($data =~ /($_)[\s,]/i){
					$fs = $1;
					$fs = main::trimmer($fs);
					last;
				}
			}
		}
	}
	main::log_data('data',"fs: $fs") if $b_log;
	eval $end if $b_log;
	return $fs;
}
}

## UsbItem
{