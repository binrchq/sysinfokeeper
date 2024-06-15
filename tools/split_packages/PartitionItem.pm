package PartitionItem;

sub get {
	eval $start if $b_log;
	my ($key1,$val1);
	my $rows = [];
	my $num = 0;
	set_partitions() if !$loaded{'set-partitions'};
	# Fails in corner case with zram but no other mounted filesystems
 	if (!@partitions){
		$key1 = 'Message';
		#$val1 = ($bsd_type && $bsd_type eq 'darwin') ? 
		# main::message('darwin-feature') : main::message('partition-data');
		$val1 = main::message('partition-data');
		@$rows = ({main::key($num++,0,1,$key1) => $val1,});
 	}
 	else {
		create_output($rows);
 	}
	eval $end if $b_log;
	return $rows;
}

sub create_output {
	eval $start if $b_log;
	my $rows = $_[0];
	my $num = 0;
	my $j = 0;
	my ($dev,$dev_type,$fs,$percent,$raw_size,$size,$used);
	# alpha sort for non numerics
	if ($show{'partition-sort'} !~ /^(percent-used|size|used)$/){
		@partitions = sort { $a->{$show{'partition-sort'}} cmp $b->{$show{'partition-sort'}} } @partitions;
	}
	else {
		@partitions = sort { $a->{$show{'partition-sort'}} <=> $b->{$show{'partition-sort'}} } @partitions;
	}
	my $fs_skip = get_filters('fs-skip');
	foreach my $row (@partitions){
		$num = 1;
		next if $row->{'type'} eq 'secondary' && $show{'partition'};
		next if $show{'swap'} && $row->{'fs'} && $row->{'fs'} eq 'swap';
		next if $row->{'swap-type'} && $row->{'swap-type'} ne 'partition';
		if (!$row->{'hidden'}){
			$size = ($row->{'size'}) ? main::get_size($row->{'size'},'string') : 'N/A';
			$used = main::get_size($row->{'used'},'string','N/A'); # used can be 0
			$percent = (defined $row->{'percent-used'}) ? ' (' . $row->{'percent-used'} . '%)' : '';
		}
		else {
			$percent = '';
			$used = $size = (!$b_root) ? main::message('root-required') : main::message('partition-hidden');
		}
		$fs = ($row->{'fs'}) ? lc($row->{'fs'}): 'N/A';
		$dev_type = ($row->{'dev-type'}) ? $row->{'dev-type'} : 'dev';
		$row->{'dev-base'} = '/dev/' . $row->{'dev-base'} if $dev_type eq 'dev' && $row->{'dev-base'};
		$dev = ($row->{'dev-base'}) ? $row->{'dev-base'} : 'N/A';
		$row->{'id'} =~ s|/home/[^/]+/(.*)|/home/$filter_string/$1| if $use{'filter'};
		$j = scalar @$rows;
		push(@$rows, {
		main::key($num++,1,1,'ID') => $row->{'id'},
		});
		if (($b_admin || $row->{'hidden'}) && $row->{'raw-size'}){
			# It's an error! permissions or missing tool
			$raw_size = ($row->{'raw-size'}) ? main::get_size($row->{'raw-size'},'string') : 'N/A';
			$rows->[$j]{main::key($num++,0,2,'raw-size')} = $raw_size;
		}
		if ($b_admin && $row->{'raw-available'} && $size ne 'N/A'){
			$size .=  ' (' . $row->{'raw-available'} . '%)';
		}
		$rows->[$j]{main::key($num++,0,2,'size')} = $size;
		$rows->[$j]{main::key($num++,0,2,'used')} = $used . $percent;
		$rows->[$j]{main::key($num++,0,2,'fs')} = $fs;
		if ($b_admin && $fs eq 'swap' && defined $row->{'swappiness'}){
			$rows->[$j]{main::key($num++,0,2,'swappiness')} = $row->{'swappiness'};
		}
		if ($b_admin && $fs eq 'swap' && defined $row->{'cache-pressure'}){
			$rows->[$j]{main::key($num++,0,2,'cache-pressure')} = $row->{'cache-pressure'};
		}
		if ($extra > 1 && $fs eq 'swap' && defined $row->{'priority'}){
			$rows->[$j]{main::key($num++,0,2,'priority')} = $row->{'priority'};
		}
		if ($b_admin && $row->{'block-size'}){
			$rows->[$j]{main::key($num++,0,2,'block-size')} = $row->{'block-size'} . ' B';;
			# $rows->[$j]{main::key($num++,0,2,'physical')} = $row->{'block-size'} . ' B';
			# $rows->[$j]{main::key($num++,0,2,'logical')} = $row->{'block-logical'} . ' B';
		}
		$rows->[$j]{main::key($num++,1,2,$dev_type)} = $dev;
		if ($b_admin && $row->{'maj-min'}){
			$rows->[$j]{main::key($num++,0,3,'maj-min')} = $row->{'maj-min'};
		}
		if ($extra > 0 && $row->{'dev-mapped'}){
			$rows->[$j]{main::key($num++,0,3,'mapped')} = $row->{'dev-mapped'};
		}
		# add fs known to not use label/uuid here
		if (($show{'label'} || $show{'uuid'}) && $dev_type eq 'dev' && 
		 $fs !~ /^$fs_skip$/){
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
	# Corner case, no partitions, but zram swap.
	if (!@$rows){
		@$rows = ({main::key($num++,0,1,'Message') => main::message('partition-data')});
	}
	eval $end if $b_log;
}

sub set_partitions {
	eval $start if $b_log;
	# return if $bsd_type && $bsd_type eq 'darwin'; # darwin has mutated output
	my (@data,@rows,@mount,@partitions_working,$part,@working);
	my ($back_size,$back_used,$b_fs,$cols) = (4,3,1,6);
	my ($b_dfp,$b_fake_map,$b_load,$b_logical,$b_space,);
	my ($block_size,$blockdev,$dev_base,$dev_mapped,$dev_type,$fs,$id,$label,
	$maj_min,$percent_used,$raw_size,$replace,$size_available,$size,$test,
	$type,$uuid,$used);
	$loaded{'set-partitions'} = 1;
	if ($b_admin){
		# For partition block size
		$blockdev = $alerts{'blockdev'}->{'path'} if $alerts{'blockdev'}->{'path'};
	}
	# For raw partition sizes, maj_min
	if ($bsd_type){
		DiskDataBSD::set() if !$loaded{'disk-data-bsd'};
	}
	else {
		PartitionData::set() if !$loaded{'partition-data'};
		LsblkData::set() if !$loaded{'lsblk'};
	}
	# set @labels, @uuid
	if (!$bsd_type){
		set_label_uuid() if !$loaded{'label-uuid'};
	}
	# Most current OS support -T and -k, but -P means different things
	# in freebsd. However since most use is from linux, we make that default
	# android 7 no -T support
	if (!$fake{'partitions'}){
		if (@partitions_working = main::grabber("df -P -T -k 2>/dev/null")){
			main::set_mapper() if !$loaded{'mapper'} && !$bsd_type;
			$b_dfp = 1;
		}
		elsif (@partitions_working = main::grabber("df -T -k 2>/dev/null")){
			# Fine, it worked, could be bsd or linux
		}
		# Busybox supports -k and -P, older openbsd, darwin, solaris don't have -P
		else {
			if (@partitions_working = main::grabber("df -k -P 2>/dev/null")){
				$b_dfp = 1;
			}
			else {
				@partitions_working = main::grabber("df -k 2>/dev/null");
			}
			$b_fs = 0;
			if (my $path = main::check_program('mount')){
				@mount = main::grabber("$path 2>/dev/null");
			}
		}
	}
	else {
		 my $file;
		# $file = "$fake_data_dir/block-devices/df/df-kTP-cygwin-1.txt";
		# $file = "$fake_data_dir/block-devices/df/df-kT-wrapped-1.txt";
		# @partitions_working = main::reader($file);
	}
	# NOTE: add push(@partitions_working,'data') here to emulate item; match unmounted
	# print Data::Dumper::Dumper \@partitions_working;
	# Determine positions
	if (@partitions_working){
		my $row1 = shift @partitions_working;
		$row1 =~ s/Mounted on/Mounted-on/i;
		my @temp = split(/\s+/,$row1);
		$cols = $#temp;
	}
	# NOTE: using -P fixes line wraps, otherwise look for hangs and reconnect
	if (!$b_dfp){ 
		my $holder = '';
		my @part_temp;
		foreach (@partitions_working){
			my @columns= split(/\s+/,$_);
			if ($#columns < $cols){
				$holder = join('^^',@columns[0..$#columns]);
				next;
			}
			if ($holder){ # reconnect hanging lines
				$_ = $holder . ' ' . $_;
				$holder = '';
			}
			push(@part_temp,$_);
		}
		@partitions_working = @part_temp;
	}
	if (!$bsd_type){
		# New kernels/df have rootfs and / repeated, creating two entries for the 
		# same partition so check for two string endings of / then slice out the 
		# rootfs one, I could check for it before slicing it out, but doing that 
		# would require the same action twice re code execution.
		my $roots = 0;
		foreach (@partitions_working){
			$roots++ if /\s\/$/;
		}
		@partitions_working = grep {!/^rootfs/} @partitions_working if $roots > 1;
	}
	else {
		# turns out freebsd uses this junk too
		$b_fake_map = 1;
		# darwin k: Filesystem 1024-blocks Used Available Capacity iused ifree %iused Mounted on
		# linux kT: Filesystem Type 1K-blocks Used Available Use% Mounted on
		# freebsd kT: Filesystem Type 1024-blocks Used Avail Capacity Mounted on
		if ($bsd_type eq 'darwin'){
			($back_size,$back_used) = (7,6);
		}
	}
	my $filters = get_filters('partition');
	# These are local, not remote, iso, or overlay types: 
	my $fuse_fs = 'adb|apfs(-?fuse)?|archive(mount)?|gphoto|gv|gzip|ifuse|';
	$fuse_fs .= '[^\.]*mtp|ntfs-?3g|[^\.]*ptp|vdfuse|vram|wim(mount)?|xb|xml';
	# Just the common ones desktops might have
	my $remote_fs = 'curlftp|gmail|g(oogle-?)?drive|pnfs|\bnfs|rclone|';
	$remote_fs .= 's3fs|smb|ssh|vboxsf';
	# push @partitions_working, '//mafreebox.freebox.fr/Disque dur cifs         239216096  206434016  20607496      91% /freebox/Disque dur';
	# push @partitions_working, '//mafreebox.freebox.fr/AllPG      cifs         436616192  316339304 120276888      73% /freebox/AllPG';
	# push(@partitions_working,'/dev/loop0p1                  iso9660         3424256   3424256           0     100% /media/jason/d-live nf 11.3.0 gn 6555 9555 amd64');
	# push(@partitions_working,'drvfs          9p        511881212 115074772  396806440      23% /mnt/c');
	# push(@partitions_working,'drivers        9p        511881212 115074772  396806440      23% /usr/lib/wsl/drivers');
	foreach (@partitions_working){
		($dev_base,$dev_mapped,$dev_type,$fs,$id,$label,
		$maj_min,$type,$uuid) = ('','','','','','','','','');
		($b_load,$b_space,$block_size,$percent_used,$raw_size,$size_available,
		$size,$used) = (0,0,0,0,0,0,0,0);
		undef $part;
		# apple crap, maybe also freebsd?
		$_ =~ s/^map\s+([\S]+)/map:\/$1/ if $b_fake_map;
		# handle spaces in remote filesystem names
		# busybox df shows KM, sigh; note: GoogleDrive Hogne: fuse.rclone 15728640 316339304 120276888 73%
		if (/^(.*?)(\s[\S]+)\s+[a-z][a-z0-9\.]+(\s+[0-9]+){3}\s+[0-9]+%\s/){
			$replace = $test = "$1$2";
			if ($test =~ /\s/){ # paranoid test, but better safe than sorry
				$b_space = 1;
				$replace =~ s/\s/^^/g;
				# print ":$replace:\n";
				$_ =~ s/^$test/$replace/;
				# print "$_\n";
			}
		}
		my @row = split(/\s+/, $_);
		# print Data::Dumper::Dumper \@row;
		$row[0] =~ s/\^\^/ /g if $b_space; # reset spaces in > 1 word fs name
		# autofs is a bsd thing, has size 0
		if ($row[0] =~ /^$filters$/ || $row[0] =~ /^ROOT/i || 
		($b_fs && ($row[2] == 0 || $row[1] =~ /^(autofs|devtmpfs|iso9660|tmpfs)$/))){
			next;
		}
		# print "row 0:", $row[0],"\n";
		# cygwin C:\cygwin passes this test so has to be handled later
		if ($row[0] =~ /^\/dev\/|:\/|\/\//){
			# this could point to by-label or by-uuid so get that first. In theory, abs_path should 
			# drill down to get the real path, but it isn't always working.
			if ($row[0] eq '/dev/root'){
				$row[0] = get_root();
			}
			# sometimes paths are set using /dev/disk/by-[label|uuid] so we need to get the /dev/xxx path
			if ($row[0] =~ /by-label|by-uuid/){
				$row[0] = Cwd::abs_path($row[0]);
			}
			elsif ($row[0] =~ /mapper\// && %mapper){
				$dev_mapped = $row[0];
				$dev_mapped =~ s|^/.*/||;
				$row[0] = $mapper{$dev_mapped} if $mapper{$dev_mapped};
			}
			elsif ($row[0] =~ /\/dm-[0-9]+$/ && %dmmapper){
				my $temp = $row[0];
				$temp =~ s|^/.*/||;
				$dev_mapped = $dmmapper{$temp};
			}
			elsif ($bsd_type && $row[0] =~ m|^/dev/gpt[^/]*/|){
				my $temp1 = $row[0];
				$temp1 =~ s|^/dev/||; 
				my $temp2 = GlabelData::get($temp1);
				if ($temp2 && $temp2 ne $temp1){
					$dev_mapped = $row[0];
					$row[0] = $temp2;
				}
			}
			$dev_base = $row[0];
			$dev_base =~ s|^/.*/||;
			$part = LsblkData::get($dev_base) if @lsblk;
			$maj_min = get_maj_min($dev_base) if @proc_partitions;
		}
		# this handles zfs type devices/partitions, which do not start with / but contain /
		# note: Main/jails/transmission_1 path can be > 1 deep 
		# Main zfs 3678031340 8156 3678023184 0% /mnt/Main
		if (!$dev_base && ($row[0] =~ /^([^\/]+\/)(.+)/ || 
		($row[0] =~ /^[^\/]+$/ && $row[1] =~ /^(btrfs|hammer[2-9]?|zfs)$/)) ||
		($windows{'wsl'} && $row[0] eq 'drivers')){
			$dev_base = $row[0];
			$dev_type = 'logical';
		}
		# this handles yet another fredforfaen special case where a mounted drive
		# has the search string in its name, includes / (|
		if ($row[-1] =~ m%^/(|boot|boot/efi|home|opt|tmp|usr|usr/home|var|var/log|var/tmp)$% ||
		($b_android && $row[-1] =~ /^\/(cache|data|firmware|system)$/)){
			$b_load = 1;
			# note, older df in bsd do not have file system column
			$type = 'main';
		}
		# $cols in case where mount point has space in name, we only care about the first part
		elsif ($row[$cols] !~ m%^\/(|boot|boot/efi|home|opt|tmp|usr|usr/home|var|var/log|var/tmp)$% &&
		 $row[$cols] !~ /^filesystem/ && 
		 !($b_android && $row[$cols] =~ /^\/(cache|data|firmware|system)$/)){
			$b_load = 1;
			$type = 'secondary';
		}
		if ($b_load){
			if (!$bsd_type){
				if ($b_fs){
					$fs = ($part->{'fs'}) ? $part->{'fs'} : $row[1];
				}
				else {
					$fs = get_mounts_fs($row[0],\@mount);
				}
				if ($show{'label'}){
					if ($part->{'label'}){
						$label = $part->{'label'};
					}
					elsif (@labels){
						$label = get_label($row[0]);
					}
				}
				if ($show{'uuid'}){
					if ($part->{'uuid'}){
						$uuid = $part->{'uuid'};
					}
					elsif (@uuids){
						$uuid = get_uuid($row[0]);
					}
				}
			}
			else {
				$fs = ($b_fs) ? $row[1]: get_mounts_fs($row[0],\@mount);
			}
			# assuming that all null/nullfs are parts of a logical fs
			$b_logical = 1 if $fs && $fs =~ /^(btrfs|hammer|null|zfs)/; 
			$id = join(' ', @row[$cols .. $#row]);
			$size = $row[$cols - $back_size];
			if ($b_admin && -e "/sys/block/"){
				@working = admin_data($blockdev,$dev_base,$size);
				$raw_size = $working[0];
				$size_available = $working[1];
				$block_size = $working[2];
			}
			if (!$dev_type){
				# C:/cygwin64, D:
				if ($windows{'cygwin'} && $row[0] =~ /^[A-Z]+:/){
					$dev_type = 'windows';
					$dev_base = $row[0] if !$dev_base;
					# looks weird if D:, yes, I know, windows uses \, but cygwin doesn't
					$dev_base .= '/' if $dev_base =~ /:$/; 
				}
				elsif ($windows{'wsl'} && $row[0] =~ /^(drvfs)/){
					$dev_type = 'windows';
					if ($id =~ m|^/mnt/([a-z])$|){
						$dev_base = uc($1) . ':';
					}
					$dev_base = $row[0] if !$dev_base;
				}
				# need data set, this could maybe be converted to use 
				# dev-mapped and abspath but not without testing
				elsif ($dev_base =~ /^map:\/(.*)/){
					$dev_type = 'mapped';
					$dev_base = $1;
				}
				# note: possible: sshfs path: beta:data/; remote: fuse.rclone
				elsif ($dev_base =~ /^\/\/|:\// || ($fs && $fs =~ /($remote_fs)/i)){
					$dev_type = 'remote';
					$dev_base = $row[0] if !$dev_base; # only trips in fs test case
				}
				# a slice bsd system, zfs can't be detected this easily
				elsif ($b_logical && $fs && $fs =~ /^null(fs)?$/){
					$dev_type = 'logical';
					$dev_base = $row[0] if !$dev_base;
				}
				elsif (!$dev_base){
					if ($fs && $fs =~ /^(fuse[\._-]?)?($fuse_fs)(fs)?/i){
						$dev_base = $2;
						$dev_type = 'fuse';
					}
					# Check dm-crypt, that may be real partition type, but no data.
					# We've hit something inxi doesn't know about, or error has occured
					else {
						$dev_type = 'source';
						$dev_base = main::message('unknown-dev');
					}
				}
				else {
					$dev_type = 'dev';
				}
			}
			if ($bsd_type && $dev_type eq 'dev' && $row[0] && 
			 ($b_admin || $show{'label'} || $show{'uuid'})){
				my $temp = DiskDataBSD::get($row[0]);
				$block_size = $temp->{'logical-block-size'};
				$label = $temp->{'label'};
				$uuid = $temp->{'uuid'};
			}
			$used = $row[$cols - $back_used];
			$percent_used = sprintf("%.1f", ($used/$size)*100) if ($size && main::is_numeric($size));
			push(@partitions,{
			'block-size' => $block_size,
			'dev-base' => $dev_base,
			'dev-mapped' => $dev_mapped,
			'dev-type' => $dev_type,
			'fs' => $fs,
			'id' => $id,
			'label' => $label,
			'maj-min' => $maj_min,
			'percent-used' => $percent_used,
			'raw-available' => $size_available,
			'raw-size' => $raw_size,
			'size' => $size,
			'type' => $type,
			'used' => $used,
			'uuid' => $uuid,
			});
		}
	}
	swap_data() if !$loaded{'set-swap'};
	push(@partitions,@swaps);
	print Data::Dumper::Dumper \@partitions if $dbg[16];
	if (!$bsd_type && @lsblk){
		check_partition_data();# updates @partitions 
	}
	main::log_data('dump','@partitions',\@partitions) if $b_log;
	print Data::Dumper::Dumper \@partitions if $dbg[16];
	eval $end if $b_log;
}

sub swap_data {
	eval $start if $b_log;
	$loaded{'set-swap'} = 1;
	my (@data,@working);
	my ($block_size,$cache_pressure,$dev_base,$dev_mapped,$dev_type,$label,
	$maj_min,$mount,$path,$pattern1,$pattern2,$percent_used,$priority,
	$size,$swap_type,$swappiness,$used,$uuid,$zram_comp,$zram_mcs,
	$zswap_enabled,$zram_comp_avail,$zswap_comp,$zswap_mpp);
	my ($s,$j,$size_id,$used_id) = (1,0,2,3);
	if (!$bsd_type){
		# faster, avoid subshell, same as swapon -s
		if (-r '/proc/swaps'){
			@working = main::reader("/proc/swaps");
		}
		elsif ($path = main::check_program('swapon')){
			# note: while -s is deprecated, --show --bytes is not supported
			# on older systems
			@working = main::grabber("$path -s 2>/dev/null");
		}
		if ($b_admin){
			swap_advanced_data(\$swappiness,\$cache_pressure,\$zswap_enabled,
			\$zswap_comp,\$zswap_mpp);
		}
		if (($show{'label'} || $show{'uuid'}) && !$loaded{'label-uuid'}){
			set_label_uuid();
		}
		$pattern1 = 'partition|file|ram';
		$pattern2 = '[^\s].*[^\s]';
	}
	else {
		if ($path = main::check_program('swapctl')){
			# output in in KB blocks$mount
			@working = main::grabber("$path -l -k 2>/dev/null");
		}
		($size_id,$used_id) = (1,2);
		$pattern1 = '[0-9]+';
		$pattern2 = '[^\s]+';
	}
	# now add the swap partition data, don't want to show swap files, just partitions,
	# though this can include /dev/ramzswap0. Note: you can also use /proc/swaps for this
	# data, it's the same exact output as swapon -s
	foreach my $line (@working){
		#next if ! /^\/dev/ || /^\/dev\/(ramzwap|zram)/;
		next if $line =~ /^(Device|Filename|no swap)/;
		($block_size,$dev_base,$dev_mapped,$dev_type,$label,$maj_min,$mount,
		$swap_type,$uuid) = ('','','','','','','','partition','');
		($priority,$zram_comp_avail,$zram_comp,$zram_mcs) = ();
		@data = split(/\s+/, $line);
		# /dev/zramX; ramzswapX == compcache, legacy version of zram.
		# /run/initramfs/dev/zram0; /dev/ramzswap0 
		if ($line =~ /^\/(dev|run).*?\/((compcache|ramzwap|zram)\d+)/i){
			$dev_base = $2;
			$swap_type = 'zram';
			$dev_type = 'dev';
			if ($b_admin){
				zram_data($dev_base,\$zram_comp,\$zram_comp_avail,\$zram_mcs);
			}
		}
		elsif ($data[1] && $data[1] eq 'ram'){
			$swap_type = 'ram';
		}
		elsif ($line =~ m|^/dev|){
			$swap_type = 'partition';
			$dev_base = $data[0];
			$dev_base =~ s|^/dev/||;
			if (!$bsd_type){
				if ($dev_base =~ /^dm-/ && %dmmapper){
					$dev_mapped = $dmmapper{$dev_base};
				}
				if ($show{'label'} && @labels){
					$label = get_label($data[0]);
				}
				if ($show{'uuid'} && @uuids){
					$uuid = get_uuid($data[0]);
				}
			}
			else {
				my $part_id = $dev_base;
				if ($dev_base =~ m|^gpt[^/]*/|){
					my $temp = GlabelData::get($dev_base);
					if ($temp && $temp ne $dev_base){
						$dev_mapped = '/dev/' . $dev_base;
						$part_id = $dev_base = $temp;
						$mount = '/dev/' . $temp;
					}
				}
				if ($show{'label'} || $show{'uuid'}){
					my $temp = DiskDataBSD::get($part_id);
					$block_size = $temp->{'logical-block-size'};
					$label = $temp->{'label'};
					$uuid = $temp->{'uuid'};
				}
			}
			$dev_type = 'dev';
			$maj_min = get_maj_min($dev_base) if @proc_partitions;
		}
		elsif ($data[1] && $data[1] eq 'file' || m|^/|){
			$swap_type = 'file';
		}
		$priority = $data[-1] if !$bsd_type;
		# swpaon -s: /dev/sdb1 partition 16383996 109608  -2
		# swapctl -l -k: /dev/label/swap0.eli     524284     154092
		# users could have space in swapfile name
		if (!$mount && $line =~ /^($pattern2)\s+($pattern1)\s+/){
			$mount = main::trimmer($1);
		}
		$size = $data[$size_id];
		$used = $data[$used_id];
		$percent_used = sprintf("%.1f", ($used/$size)*100);
		push(@swaps, {
		'block-size' => $block_size,
		'cache-pressure' => $cache_pressure,
		'dev-base' => $dev_base,
		'dev-mapped' => $dev_mapped,
		'dev-type' => $dev_type,
		'fs' => 'swap',
		'id' => "swap-$s",
		'label' => $label,
		'maj-min' => $maj_min,
		'mount' => $mount,
		'percent-used' => $percent_used,
		'priority' => $priority,
		'size' => $size,
		'swappiness' => $swappiness,
		'type' => 'main',
		'swap-type' => $swap_type,
		'used' => $used,
		'uuid' => $uuid,
		'zram-comp' => $zram_comp,
		'zram-comp-avail' => $zram_comp_avail,
		'zram-max-comp-streams' => $zram_mcs,
		'zswap-enabled' => $zswap_enabled,
		'zswap-compressor' => $zswap_comp,
		'zswap-max-pool-percent' => $zswap_mpp,
		});
		$s++;
	}
	main::log_data('dump','@swaps',\@swaps) if $b_log;
	print Data::Dumper::Dumper \@swaps if $dbg[15];;
	eval $end if $b_log;
}

# Alll by ref: 0: $swappiness; 1: $cache_pressure; 2: $zswap_enabled;
# 3: $zswap_comp; 4: $zswap_mpp
sub swap_advanced_data {
	eval $start if $b_log;
	if (-r '/proc/sys/vm/swappiness'){
		${$_[0]} = main::reader('/proc/sys/vm/swappiness','',0);
		if (defined ${$_[0]}){
			${$_[0]} .= (${$_[0]} == 60) ? ' (default)' : ' (default 60)' ;
		}
	}
	if (-r '/proc/sys/vm/vfs_cache_pressure'){
		${$_[1]} = main::reader('/proc/sys/vm/vfs_cache_pressure','',0);
		if (defined ${$_[1]}){
			${$_[1]} .= (${$_[1]}== 100) ? ' (default)' : ' (default 100)' ;
		}
	}
	if (-r '/sys/module/zswap/parameters/enabled'){
		${$_[2]} = main::reader('/sys/module/zswap/parameters/enabled','',0);
		if (${$_[2]} =~ /^(Y|yes|true|1)$/){
			${$_[2]} = 'yes';
		}
		elsif (${$_[2]} =~ /^(N|no|false|0)$/){
			${$_[2]} = 'no';
		}
		else {
			${$_[2]} = 'unset';
		}
	}
	if (-r '/sys/module/zswap/parameters/compressor'){
		${$_[3]} = main::reader('/sys/module/zswap/parameters/compressor','',0);
	}
	if (-r '/sys/module/zswap/parameters/max_pool_percent'){
		${$_[4]} = main::reader('/sys/module/zswap/parameters/max_pool_percent','',0);
	}
	eval $end if $b_log;
}

# 0: device id [zram0]; by ref: 1: $zram_comp; 2: $zram_comp_avail; 3: $zram_mcs; 
sub zram_data {
	if (-r "/sys/block/$_[0]/comp_algorithm"){
		${$_[2]} = main::reader("/sys/block/$_[0]/comp_algorithm",'',0);
		# current is in [..] in list
		if (${$_[2]} =~ /\[(\S+)\]/){
			${$_[1]} = $1;
			# dump the active one, and leave the available
			${$_[2]} =~ s/\[${$_[1]}\]//;
			${$_[2]} =~ s/^\s+|\s+$//g;
			${$_[2]} =~ s/\s+/,/g;
		}
	}
	if (-r "/sys/block/$_[0]/max_comp_streams"){
		${$_[3]} = main::reader("/sys/block/$_[0]/max_comp_streams",'',0);
	}
}

# Handle cases of hidden file systems
sub check_partition_data {
	eval $start if $b_log;
	my ($b_found,$dev_mapped,$temp);
	my $filters = get_filters('partition');
	foreach my $row (@lsblk){
		$b_found = 0;
		$dev_mapped = '';
		if (!$row->{'name'} || !$row->{'mount'} || !$row->{'type'} || 
		 ($row->{'fs'} && $row->{'fs'} =~ /^$filters$/) ||
		 ($row->{'type'} =~ /^(disk|loop|rom)$/)){
			next;
		}
		# unmap so we can match name to dev-base
		if (%mapper && $mapper{$row->{'name'}}){
			$dev_mapped = $row->{'name'};
			$row->{'name'} = $mapper{$row->{'name'}};
		}
		# print "$row->{'name'} $row->{'mount'}\n";
		foreach my $row2 (@partitions){
			# print "1: n:$row->{'name'} m:$row->{'mount'} db:$row2->{'dev-base'} id:$row2->{'id'}\n";
			next if !$row2->{'id'};
			# note: for swap mount point is [SWAP] in @lsblk, but swap-x in @partitions
			if ($row->{'mount'} eq $row2->{'id'} || $row->{'name'} eq $row2->{'dev-base'}){
				$b_found = 1;
				last;
			}
			# print "m:$row->{'mount'} id:$row2->{'id'}\n";
		}
		if (!$b_found){
			# print "found: n:$row->{'name'} m:$row->{'mount'}\n";
			$temp = {
			'block-logical' => $row->{'block-logical'},
			'dev-base' => $row->{'name'},
			'dev-mapped' => $dev_mapped,
			'fs' => $row->{'fs'},
			'id' => $row->{'mount'},
			'hidden' => 1,
			'label' => $row->{'label'},
			'maj-min' => $row->{'maj-min'},
			'percent-used' => 0,
			'raw-size' => $row->{'size'},
			'size' => 0,
			'type' => 'secondary',
			'used' => 0,
			'uuid' => $row->{'uuid'},
			};
			push(@partitions,$temp);
			main::log_data('dump','lsblk check: @temp',$temp) if $b_log;
		}
	}
	eval $end if $b_log;
}

# fs-exclude: Excludes fs size from disk used total; 
# fs-skip: do not display label/uuid fields from partition/unmounted/swap.
# partition: do not use this partition in -p output.
# args: 0: [fs-exclude|fs-skip|partition]
sub get_filters {
	set_filters() if !$fs_exclude;
	if ($_[0] eq 'fs-exclude'){
		return $fs_exclude;
	}
	elsif ($_[0] eq 'fs-skip'){
		return $fs_skip;
	}
	elsif ($_[0] eq 'partition'){
		return $part_filter;
	}
}

# See docs/inxi-partitions.txt FILE SYSTEMS for specific fs info.
# The filter string must match /^[regex]$/ exactly.
sub set_filters {
	# Notes: appimage/flatpak mount?; astreamfs reads remote http urls; 
	#  avfs == fuse; cgmfs,vramfs in ram, like devfs, sysfs; gfs = googlefs; 
	#  hdfs == hadoop; ifs == integrated fs; pvfs == orangefs; smb == cifs; 
	#  null == hammer fs slice; kfs/kosmosfs == CloudStore; 
	#  snap mounts with squashfs; swap is set in swap_data(); vdfs != vdfuse; 
	#  vramfs == like zram except gpu ram;
	#  Some can be fuse mounts: fuse.sshfs.
	# Distributed/Remote: 9p, (open-)?afs, alluxio, astreamfs, beegfs, 
	#  cephfs, cfs, chironfs, cifs, cloudstore, dfs, davfs, dce,
	#  gdrivefs, gfarm, gfs\d{0,2}, gitfs, glusterfs, gmailfs, gpfs,
	#  hdfs, httpdirfs, hubicfuse, ipfs, juice, k(osmos)?fs, .*lafs, lizardfs,
	#  lustre, magma, mapr, moosefs, nfs[34], objective, ocfs\d{0,2}, onefs, 
	#  orangefs, panfs, pnfs, pvfs\d{0,2}, rclone, restic, rozofs, s3fs, scality,
	#  sfs, sheepdogfs, spfs, sshfs, smbfs, v9fs, vboxsf, vdfs, vmfs, wekafs, 
	#  xtreemfs
	# Stackable/Union: aufs, e?cryptfs, encfs, erofs, gocryptfs, ifs, lofs, 
	#  mergerfs, mhddfs, overla(id|y)(fs)?, squashfs, unionfs;
	# ISO/Archive: archive(mount)?, atlas, avfs. borg, erofs, fuse-archive, 
	#  fuseiso, gzipfs, iso9660, lofs, vdfuse, wimmountfs, xbfuse
	# FUSE: adbfs, apfs-fuse, atomfs, gvfs, gvfs-mtp, ifuse, jmtpfs, mtpfs, ptpfs, 
	#  puzzlefs, simple-mtpfs, vramfs, xmlfs
	# System fs: cgmfs, configfs, debugfs, devfs, devtmpfs, efivarfs, fdescfs, 
	#  hugetlbfs, kernfs, linprocfs, linsysfs, lxcfs, procfs, ptyfs, run, 
	#  securityfs, shm, swap, sys, sysfs, tmpfs, tracefs, type, udev, vartmp
	# System dir: /dev, /dev/(block/)?loop[0-9]+, /run(/.*)?, /sys/.*
	
	## These are global, all filters use these. ISO, encrypted/stacked
	my @all = qw%au av e?crypt enc ero gocrypt i (fuse-?)?iso iso9660 lo merger 
	mhdd overla(id|y) splitview(-?fuse)? squash union vboxsf xbfuse%;
	## These are fuse/archive/distributed/remote/clustered mostly
	my @exclude = (@all,qw%9p (open-?)?a adb archive(mount)? astream atlas atom
	beeg borg c ceph chiron ci cloudstore curlftp d dav dce 
	g gdrive gfarm git gluster gmail gocrypt google-drive-ocaml gp gphoto gv gzip
	hd httpd hubic ip juice k(osmos)? .*la lizard lustre magma mapr moose .*mtp 
	null p?n objective oc one orange pan .*ptp puzzle pv rclone restic rozo 
	s s3 scality sheepdog sp ssh smb v9 vd vm vram weka wim(mount)? xb xml 
	xtreem%);
	# Various RAM based system FS
	my @partition = (@all,qw%cgroup.* cgm config debug dev devtmp efivar fdesc 
	hugetlb kern linproc linsys lxc none proc pty run security shm swap sys 
	tmp trace type udev vartmp%);
	my $begin = '(fuse(blk)?[\._-]?)?(';
	my $end = ')([\._-]?fuse)?(fs)?\d{0,2}';
	$fs_exclude = $begin . join('|',@exclude) . $end;
	$fs_skip = $begin . join('|',@exclude,'f') . $end; # apfs?; BSD ffs has no u/l
	$part_filter = '((' . join('|',@partition) . ')(fs)?|';
	$part_filter .= '\/dev|\/dev\/(block\/)?loop[0-9]+|\/run(\/.*)?|\/sys\/.*)'; 
	# print "$part_filter\n";
}

sub get_mounts_fs {
	eval $start if $b_log;
	my ($item,$mount) = @_;
	$item =~ s/map:\/(\S+)/map $1/ if $bsd_type && $bsd_type eq 'darwin';
	return 'N/A' if ! @$mount;
	my ($fs) = ('');
	# linux: /dev/sdb6 on /var/www/m type ext4 (rw,relatime,data=ordered)
	# /dev/sda3 on /root.dev/ugw type ext3 (rw,relatime,errors=continue,user_xattr,acl,barrier=1,data=journal)
	# bsd: /dev/ada0s1a on / (ufs, local, soft-updates)
	# bsd 2: /dev/wd0g on /home type ffs (local, nodev, nosuid)
	foreach (@$mount){
		if ($_ =~ /^$item\s+on.*?\s+type\s+([\S]+)\s+\([^\)]+\)/){
			$fs = $1;
			last;
		}
		elsif ($_ =~ /^$item\s+on.*?\s+\(([^,\s\)]+?)[,\s]*.*\)/){
			$fs = $1;
			last;
		}
	}
	eval $end if $b_log;
	main::log_data('data',"fs: $fs") if $b_log;
	return $fs;
}

sub set_label_uuid {
	eval $start if $b_log;
	$loaded{'label-uuid'} = 1;
	if ($show{'unmounted'} || $show{'label'} || $show{'swap'} || $show{'uuid'}){
		if (-d '/dev/disk/by-label'){
			@labels = main::globber('/dev/disk/by-label/*');
		}
		if (-d '/dev/disk/by-uuid'){
			@uuids = main::globber('/dev/disk/by-uuid/*');
		}
		main::log_data('dump', '@labels', \@labels) if $b_log;
		main::log_data('dump', '@uuids', \@uuids) if $b_log;
	}
	eval $end if $b_log;
}

# args: 0: blockdev full path (part only); 1: block id; 2: size (part only)
sub admin_data {
	eval $start if $b_log;
	my ($blockdev,$id,$size) = @_;
	# 0: calc block 1: available percent 2: disk physical block size/partition block size;
	my @sizes = (0,0,0); 
	my ($block_size,$percent,$size_raw) = (0,0,0);
	foreach my $row (@proc_partitions){
		if ($row->[-1] eq $id){
			$size_raw = $row->[2];
			last;
		}
	}
	# get the fs block size
	$block_size = (main::grabber("$blockdev --getbsz /dev/$id 2>/dev/null"))[0] if $blockdev;
	if (!$size_raw){
		$size_raw = 'N/A';
	}
	else {
		$percent = sprintf("%.2f", ($size/$size_raw) * 100) if $size && $size_raw;
	}
	# print "$id size: $size %: $percent p-b: $block_size raw: $size_raw\n";
	@sizes = ($size_raw,$percent,$block_size); 
	main::log_data('dump','@sizes',\@sizes) if $b_log;
	eval $end if $b_log;
	return @sizes;
}

sub get_maj_min {
	eval $start if $b_log;
	my ($id) = @_;
	my ($maj_min,@working);
	foreach my $row (@proc_partitions){
		if ($id eq $row->[-1]){
			$maj_min = $row->[0] . ':' . $row->[1];
			last;
		}
	}
	eval $end if $b_log;
	return $maj_min;
}

sub get_label {
	eval $start if $b_log;
	my ($item) = @_;
	my $label = '';
	foreach (@labels){
		if ($item eq Cwd::abs_path($_)){
			$label = $_;
			$label =~ s/\/dev\/disk\/by-label\///;
			$label =~ s/\\x20/ /g;
			$label =~ s%\\x2f%/%g;
			last;
		}
	}
	$label ||= 'N/A';
	eval $end if $b_log;
	return $label;
}

sub get_root {
	eval $start if $b_log;
	my ($path) = ('/dev/root');
	# note: the path may be a symbolic link to by-label/by-uuid but not 
	# sure how far in abs_path resolves the path.
	my $temp = Cwd::abs_path($path);
	$path = $temp if $temp;
	# note: it's a kernel config option to have /dev/root be a sym link 
	# or not, if it isn't, path will remain /dev/root, if so, then try mount
	if ($path eq '/dev/root' && (my $program = main::check_program('mount'))){
		my @data = main::grabber("$program 2>/dev/null");
		# /dev/sda2 on / type ext4 (rw,noatime,data=ordered)
		foreach (@data){
			if (/^([\S]+)\son\s\/\s/){
				$path = $1;
				# note: we'll be handing off any uuid/label paths to the next 
				# check tools after get_root() above, so don't trim those.
				$path =~ s/.*\/// if $path !~ /by-uuid|by-label/;
				last;
			}
		}
	}
	eval $end if $b_log;
	return $path;
}

sub get_uuid {
	eval $start if $b_log;
	my ($item) = @_;
	my $uuid = '';
	foreach (@uuids){
		if ($item eq Cwd::abs_path($_)){
			$uuid = $_;
			$uuid =~ s/\/dev\/disk\/by-uuid\///;
			last;
		}
	}
	$uuid ||= 'N/A';
	eval $end if $b_log;
	return $uuid;
}
}

## ProcessItem 
{