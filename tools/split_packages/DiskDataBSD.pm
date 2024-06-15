package DiskDataBSD;

# Sets initial pure dboot data, and fills it in with 
# disklabel/gpart partition and advanced data
sub set {
	eval $start if $b_log;
	$loaded{'disk-data-bsd'} = 1;
	set_dboot_disks();
	if ($use{'bsd-partition'}){
		if ($alerts{'gpart'}->{'action'} eq 'use'){
			set_gpart_data();
		}
		elsif ($alerts{'disklabel'}->{'action'} eq 'use'){
			set_disklabel_data();
		}
	}
	eval $end if $b_log;
}

sub get {
	eval $start if $b_log;
	my $id = $_[0];
	return if !$id || !%disks_bsd;
	$id =~ s|^/dev/||;
	my $data = {};
	# this handles mainly zfs, which can be either disk or part
	if ($disks_bsd{$id}){
		$data = $disks_bsd{$id};
		delete $data->{'partitions'} if $data->{'partitions'};
	}
	else {
		OUTER: foreach my $key (keys %disks_bsd){
			if ($disks_bsd{$key}->{'partitions'}){
				foreach my $part (keys %{$disks_bsd{$key}->{'partitions'}}){
					if ($part eq $id){
						$data = $disks_bsd{$key}->{'partitions'}{$part};
						last OUTER;
					}
				}
			}
		}
	}
	eval $end if $b_log;
	return $data;
}

sub set_dboot_disks {
	eval $start if $b_log;
	my ($working,@temp);
	foreach my $id (sort keys %{$dboot{'disk'}}){
		next if !@{$dboot{'disk'}->{$id}};
		foreach (@{$dboot{'disk'}->{$id}}){
			my @row = split(/:\s*/, $_);
			next if !$row[0];
			# no dots, note: ada2: 2861588MB BUT: ada2: 600.000MB/s 
			# print "$_ i: $i\n";
			# openbsd/netbsd matches will often work
			if ($row[0] =~ /(^|,\s*)([0-9\.]+\s*[MGTPE])i?B?[,.\s]+([0-9]+)\ssectors$|^</){
				$working = main::translate_size($2);
				# seen:  for some reason, size/sectors did not result in clean integer value
				$disks_bsd{$id}->{'block-physical'} = POSIX::ceil(($working/$3)*1024) if $3;
				$disks_bsd{$id}->{'size'} = $working;
			}
			# don't set both, if smartctl installed, we want to use its data so having
			# only one of logical/physical will trip use of smartctl values
			if ($row[0] =~ /[\s,]+([0-9]+)\sbytes?[\s\/]sect/){
				#$disks_bsd{$id}->{'block-logical'} = $1;
				$disks_bsd{$id}->{'block-physical'} = $1;
			}
			if ($row[1]){
				if ($row[1] =~ /<([^>]+)>/){
					$disks_bsd{$id}->{'model'} = $1 if $1;
					$disks_bsd{$id}->{'type'} = 'removable' if $_ =~ /removable/;
					# <Generic-, Compact Flash, 1.00>
					my $count = ($disks_bsd{$id}->{'model'} =~ tr/,//);
					if ($count && $count > 1){
						@temp = split(/,\s*/, $disks_bsd{$id}->{'model'});
						$disks_bsd{$id}->{'model'} = $temp[1];
					}
				}
				if ($row[1] =~ /\bserial\.(\S*)/){
					$disks_bsd{$id}->{'serial'} = $1;
				}
			}
			if (!$disks_bsd{$id}->{'serial'} && $row[0] =~ /^Serial\sNumber\s(.*)/){
				$disks_bsd{$id}->{'serial'} = $1;
			}
			# mmcsd0:32GB <SDHC SL32G 8.0 SN 27414E9E MFG 07/2014 by 3 SD> at mmc0 50.0MHz/4bit/65535-block
			if (!$disks_bsd{$id}->{'serial'} && $row[0] =~ /(\s(SN|s\/n)\s(\S+))[>\s]/){
				$disks_bsd{$id}->{'serial'} = $3;
				# strip out the SN/MFG so it won't show in model
				$row[0] =~ s/$1//;
				$row[0] =~ s/\sMFG\s[^>]+//;
			}
			# these were mainly FreeBSD/Dragonfly matches
			if (!$disks_bsd{$id}->{'size'} && $row[0] =~ /^([0-9]+\s*[KMGTPE])i?B?[\s,]/){
				$working = main::translate_size($1);
				$disks_bsd{$id}->{'size'} = $working;
			}
			if ($row[0] =~ /(device$|^([0-9\.]+\s*[KMGT]B\s+)?<)/){
				$row[0] =~ s/\bdevice$//g;
				$row[0] =~ /<([^>]*)>(\s(.*))?/;
				$disks_bsd{$id}->{'model'} = $1 if $1;
				$disks_bsd{$id}->{'spec'} = $3 if $3;
			}
			if ($row[0] =~ /^([0-9\.]+[MG][B]?\/s)/){
				$disks_bsd{$id}->{'speed'} = $1;
				$disks_bsd{$id}->{'speed'} =~ s/\.[0-9]+// if $disks_bsd{$id}->{'speed'};
			}
			$disks_bsd{$id}->{'model'} = main::clean_disk($disks_bsd{$id}->{'model'});
			if (!$disks_bsd{$id}->{'serial'} && $show{'disk'} && $extra > 1 && 
			 $alerts{'bioctl'}->{'action'} eq 'use'){
				$disks_bsd{$id}->{'serial'} = bioctl_data($id);
			}
		}
	}
	print 'dboot disk: ', Data::Dumper::Dumper \%disks_bsd if $dbg[34];
	main::log_data('dump','%disks_bsd',\%disks_bsd) if $b_log;
	eval $end if $b_log;
}

sub bioctl_data {
	eval $start if $b_log;
	my $id = $_[0];
	my $serial;
	my $working = (main::grabber($alerts{'bioctl'}->{'path'} . " $id  2>&1",'','strip'))[0];
	if ($working){
		if ($working =~ /permission/i){
			$alerts{'bioctl'}->{'action'} = 'permissions';
		}
		elsif ($working =~ /serial[\s-]?(number|n[ou]\.?)?\s+(\S+)$/i){
			$serial = $2;
		}
	}
	eval $end if $b_log;
	return $serial;
}

sub set_disklabel_data {
	eval $start if $b_log;
	my ($cmd,@data,@working);
	# see docs/inxi-data.txt for fs info
	my %fs = (
	'4.2bsd' => 'ffs',
	'4.4lfs' => 'lfs',
	);
	foreach my $id (keys %disks_bsd){
		$cmd = "$alerts{'disklabel'}->{'path'} $id 2>&1";
		@data = main::grabber($cmd,'','strip');
		main::log_data('dump','disklabel @data', \@data) if $b_log;
		if (scalar @data < 4 && (grep {/permission/i} @data)){
			$alerts{'disklabel'}->{'action'} = 'permissions';
			$alerts{'disklabel'}->{'message'} = main::message('root-feature');
			last;
		}
		else {
			my ($b_part,$duid,$part_id,$bytes_sector) = ();
			if ($extra > 2 && $show{'disk'} && $alerts{'fdisk'}->{'action'} eq 'use'){
				$disks_bsd{$id}->{'partition-table'} = fdisk_data($id);
			}
			foreach my $row (@data){
				if ($row =~ /^\d+\spartitions:/){
					$b_part = 1;
					next;
				}
				if (!$b_part){
					@working = split(/:\s*/, $row);
					if ($working[0] eq 'bytes/sector'){
						$disks_bsd{$id}->{'block-physical'} = $working[1];
						$bytes_sector = $working[1];
					}
					elsif ($working[0] eq 'duid'){
						$working[1] =~ s/^0+$//; # dump duid if all 0s
						$disks_bsd{$id}->{'duid'} = $working[1];
					}
					elsif ($working[0] eq 'label'){
						$disks_bsd{$id}->{'dlabel'} = $working[1];
					}
				}
				# part:        size [bytes*sector]      offset    fstype [fsize bsize cpg]# mount
				# d:          8388608         18838976  4.2BSD   2048 16384 12960 # /tmp
				else {
					@working = split(/:?\s+#?\s*/, $row);
					# netbsd: disklabel: super block size 0 AFTER partitions started!
					# note: 'unused' fs type is NOT unused space, it's often the entire disk!!
					if (($working[0] && $working[0] eq 'disklabel') ||
					 ($working[3] && $working[3] =~ /ISO9660|unused/i) || 
					 (!$working[1] || !main::is_numeric($working[1]))){
						next;
					}
					$part_id = $id . $working[0];
					$working[1] = $working[1]*$bytes_sector/1024 if $working[1];
					$disks_bsd{$id}->{'partitions'}{$part_id}{'size'} = $working[1];
					if ($working[3]){ # fs
						$working[3] = lc($working[3]);
						$working[3] = $fs{$working[3]} if $fs{$working[3]}; #translate
					}
					$disks_bsd{$id}->{'partitions'}{$part_id}{'fs'} = $working[3];
					# OpenBSD: mount point; NetBSD: (Cyl. 0 - 45852*)
					if ($working[7] && $working[7] =~ m|^/|){ 
						$disks_bsd{$id}->{'partitions'}{$part_id}{'mount'} = $working[7];
					}
					$disks_bsd{$id}->{'partitions'}{$part_id}{'uuid'} = '';
					$disks_bsd{$id}->{'partitions'}{$part_id}{'label'} = '';
				}
			}
		}
	}
	print 'disklabel: ', Data::Dumper::Dumper \%disks_bsd if $dbg[34];
	main::log_data('dump', '%disks_bsd', \%disks_bsd) if $b_log;
	eval $end if $b_log;
}

sub fdisk_data {
	eval $start if $b_log;
	my $id = $_[0];
	my ($scheme);
	my @data = main::grabber($alerts{'fdisk'}->{'path'} . " -v $id  2>&1",'','strip');
	foreach (@data){
		if (/permission/i){
			$alerts{'fdisk'}->{'action'} = 'permissions';
			last;
		}
		elsif (/^(GUID|MBR):/){
			$scheme = ($1 eq 'GUID') ? 'GPT' : $1;
			last;
		}
	}
	eval $start if $b_log;
	return $scheme;
}

# 2021-03: openbsd: n/a; dragonfly: no 'list'; freebsd: yes
sub set_gpart_data {
	eval $start if $b_log;
	my @data = main::grabber($alerts{'gpart'}->{'path'} . " list 2>/dev/null",'','strip');
	main::log_data('dump', 'gpart: @data', \@data) if $b_log;
	my ($b_cd,$id,$part_id,$type);
	for (@data){
		my @working = split(/\s*:\s*/, $_);
		if ($working[0] eq 'Geom name'){
			$id = $working[1];
			# [1. Name|Geom name]: iso9660/FVBE
			$b_cd = ($id =~ /iso9660/i) ? 1: 0;
			next;
		}
		elsif ($working[0] eq 'scheme'){
			$disks_bsd{$id}->{'scheme'} = $working[1];
			next;
		}
		elsif ($working[0] eq 'Consumers'){
			$type = 'disk';
			next;
		}
		elsif ($working[0] eq 'Providers'){
			$type = 'part';
			next;
		}
		if (!$b_cd && $type && $type eq 'part'){
			if ($working[0] =~ /^[0-9]+\.\s*Name/){
				$part_id = $working[1];
			}
			# eg: label:(null) - we want to show null
			elsif ($working[0] eq 'label'){
				$working[1] =~ s/\(|\)//g; 
				$disks_bsd{$id}->{'partitions'}{$part_id}{'label'} = $working[1];
			}
			elsif ($working[0] eq 'Mediasize'){
				$working[1] =~ s/\s+\(.*$//; # trim off the (2.4G)
				# gpart shows in bytes, not KiB. For the time being...
				$disks_bsd{$id}->{'partitions'}{$part_id}{'size'} = $working[1]/1024 if $working[1];
			}
			elsif ($working[0] eq 'rawuuid'){
				$working[1] =~ s/\(|\)//g; 
				$disks_bsd{$id}->{'partitions'}{$part_id}{'uuid'} = $working[1];
			}
			elsif ($working[0] eq 'Sectorsize'){
				$disks_bsd{$id}->{'partitions'}{$part_id}{'physical-block-size'} = $working[1];
			}
			elsif ($working[0] eq 'Stripesize'){
				$disks_bsd{$id}->{'partitions'}{$part_id}{'logical-block-size'} = $working[1];
			}
			elsif ($working[0] eq 'type'){
				$working[1] =~ s/\(|\)//g; 
				$disks_bsd{$id}->{'partitions'}{$part_id}{'fs'} = $working[1];
			}
		}
		# really strange results happen if no dboot disks were found and it's zfs!
		elsif (!$b_cd && $type && $type eq 'disk' && $disks_bsd{$id}->{'size'}){
			# need to see raid, may be > 1 Consumers
			if ($working[0] =~ /^[0-9]+\.\s*Name/){
				$id = $working[1];
			}
			elsif ($working[0] eq 'Mediasize'){
				$working[1] =~ s/\s+\(.*$//; # trim off the (2.4G)
				# gpart shows in bytes, not KiB. For the time being...
				$disks_bsd{$id}->{'size'} = $working[1]/1024 if $working[1];
			}
			elsif ($working[0] eq 'Sectorsize'){
				$disks_bsd{$id}->{'block-physical'} = $working[1];
			}
		}
	}
	print 'gpart: ', Data::Dumper::Dumper \%disks_bsd if $dbg[34];
	main::log_data('dump', '%disks_bsd', \%disks_bsd) if $b_log;
	eval $end if $b_log;
}
}

## DmData
# Public method: get()
# returns hash ref of array of arrays for dm/lm
# hash: dm, lm
# 0: dm/lm print name
# 1: dm/lm version
# 2: dm/lm status 
{