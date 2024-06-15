package OpticalItem;

sub get {
	eval $start if $b_log;
	my $rows = $_[0];
	my $rows_start = scalar @$rows;
	my ($data,$val1);
	my $num = 0;
	if ($bsd_type){
		$val1 = main::message('optical-data-bsd');
		if ($dboot{'optical'}){
			$data = drive_data_bsd();
			drive_output($rows,$data) if %$data;
		}
		else{
			my $file = $system_files{'dmesg-boot'};
			if ($file && ! -r $file){
				$val1 = main::message('dmesg-boot-permissions');
			}
			elsif (!$file){
				$val1 = main::message('dmesg-boot-missing');
			}
		}
	}
	else {
		$val1 = main::message('optical-data');
		$data = drive_data_linux();
		drive_output($rows,$data) if %$data;
	}
	# if none of the above increased the row count, show the error message
	if ($rows_start == scalar @$rows){
		push(@$rows,{main::key($num++,0,1,'Message') => $val1});
	}
	eval $end if $b_log;
	return $rows;
}

sub drive_output {
	eval $start if $b_log;
	my ($rows,$drives) = @_;
	my $num = 0;
	my $j = 0;
	# build floppy if any
	foreach my $key (sort keys %$drives){
		if ($drives->{$key}{'type'} eq 'floppy'){
			push(@$rows, {
			main::key($num++,0,1,ucfirst($drives->{$key}{'type'})) => "/dev/$key",
			});
			delete $drives->{$key};
		}
	}
	foreach my $key (sort keys %$drives){
		$j = scalar @$rows;
		$num = 1;
		my $vendor = $drives->{$key}{'vendor'};
		$vendor ||= 'N/A';
		my $model = $drives->{$key}{'model'};
		$model ||= 'N/A';
		push(@$rows, { 
		main::key($num++,1,1,ucfirst($drives->{$key}{'type'})) => "/dev/$key",
		main::key($num++,0,2,'vendor') => $vendor,
		main::key($num++,0,2,'model') => $model,
		});
		if ($extra > 0){
			my $rev = $drives->{$key}{'rev'};
			$rev ||= 'N/A';
			$rows->[$j]{ main::key($num++,0,2,'rev')} = $rev;
		}
		if ($extra > 1 && $drives->{$key}{'serial'}){
			$rows->[$j]{ main::key($num++,0,2,'serial')} = main::filter($drives->{$key}{'serial'});
		}
		my $links = (@{$drives->{$key}{'links'}}) ? join(',', sort @{$drives->{$key}{'links'}}) : 'N/A' ;
		$rows->[$j]{ main::key($num++,0,2,'dev-links')} = $links;
		if ($show{'optical'}){
			$j = scalar @$rows;
			my $speed = $drives->{$key}{'speed'};
			$speed ||= 'N/A';
			my ($audio,$multisession) = ('','');
			if (defined $drives->{$key}{'multisession'}){
				$multisession = ($drives->{$key}{'multisession'} == 1) ? 'yes' : 'no' ;
			}
			$multisession ||= 'N/A';
			if (defined $drives->{$key}{'audio'}){
				$audio = ($drives->{$key}{'audio'} == 1) ? 'yes' : 'no' ;
			}
			$audio ||= 'N/A';
			my $dvd = 'N/A';
			my (@rw,$rws);
			if (defined $drives->{$key}{'dvd'}){
				$dvd = ($drives->{$key}{'dvd'} == 1) ? 'yes' : 'no' ;
			}
			if ($drives->{$key}{'cdr'}){
				push(@rw, 'cd-r');
			}
			if ($drives->{$key}{'cdrw'}){
				push(@rw, 'cd-rw');
			}
			if ($drives->{$key}{'dvdr'}){
				push(@rw, 'dvd-r');
			}
			if ($drives->{$key}{'dvdram'}){
				push(@rw, 'dvd-ram');
			}
			$rws = (@rw) ? join(',', @rw) : 'none' ;
			push(@$rows, {
			main::key($num++,1,2,'Features') => '',
			main::key($num++,0,3,'speed') => $speed,
			main::key($num++,0,3,'multisession') => $multisession,
			main::key($num++,0,3,'audio') => $audio,
			main::key($num++,0,3,'dvd') => $dvd,
			main::key($num++,0,3,'rw') => $rws,
			});
			if ($extra > 0){
				my $state = $drives->{$key}{'state'};
				$state ||= 'N/A';
				$rows->[$j]{ main::key($num++,0,3,'state')} = $state;
			}
		}
	}
	# print Data::Dumper::Dumper $drives;
	eval $end if $b_log;
}

sub drive_data_bsd {
	eval $start if $b_log;
	my (@rows,@temp);
	my $drives = {};
	my ($count,$i,$working) = (0,0,'');
	foreach (@{$dboot{'optical'}}){
		$_ =~ s/(cd[0-9]+)\(([^:]+):([0-9]+):([0-9]+)\):/$1:$2-$3.$4,/;
		my @row = split(/:\s*/, $_);
		next if ! defined $row[1];
		if ($working ne $row[0]){
			# print "$id_holder $row[0]\n";
			$working = $row[0];
		}
		# no dots, note: ada2: 2861588MB BUT: ada2: 600.000MB/s 
		if (!exists $drives->{$working}){
			$drives->{$working}{'links'} = [];
			$drives->{$working}{'model'} = '';
			$drives->{$working}{'rev'} = '';
			$drives->{$working}{'state'} = '';
			$drives->{$working}{'vendor'} = '';
			$drives->{$working}{'temp'} = '';
			$drives->{$working}{'type'} = ($working =~ /^cd/) ? 'optical' : 'unknown';
		}
		# print "$_\n";
		if ($bsd_type !~ /^(net|open)bsd$/){
			if ($row[1] && $row[1] =~ /^<([^>]+)>/){
				$drives->{$working}{'model'} = $1;
				$count = ($drives->{$working}{'model'} =~ tr/ //);
				if ($count && $count > 1){
					@temp = split(/\s+/, $drives->{$working}{'model'});
					$drives->{$working}{'vendor'} = $temp[0];
					my $index = ($#temp > 2) ? ($#temp - 1): $#temp;
					$drives->{$working}{'model'} = join(' ', @temp[1..$index]);
					$drives->{$working}{'rev'} = $temp[-1] if $count > 2;
				}
				if ($show{'optical'}){
					if (/\bDVD\b/){
						$drives->{$working}{'dvd'} = 1;
					}
					if (/\bRW\b/){
						$drives->{$working}{'cdrw'} = 1;
						$drives->{$working}{'dvdr'} = 1 if $drives->{$working}{'dvd'};
					}
				}
			}
			if ($row[1] && $row[1] =~ /^Serial/){
				@temp = split(/\s+/,$row[1]);
				$drives->{$working}{'serial'} = $temp[-1];
			}
			if ($show{'optical'}){
				if ($row[1] =~ /^([0-9\.]+[MGTP][B]?\/s)/){
					$drives->{$working}{'speed'} = $1;
					$drives->{$working}{'speed'} =~ s/\.[0-9]+//;
				}
				if (/\bDVD[-]?RAM\b/){
					$drives->{$working}{'cdr'} = 1;
					$drives->{$working}{'dvdram'} = 1;
				}
				if ($row[2] && $row[2] =~ /,\s(.*)$/){
					$drives->{$working}{'state'} = $1;
					$drives->{$working}{'state'} =~ s/\s+-\s+/, /;
				}
			}
		}
		else {
			if ($row[2] && $row[2] =~ /<([^>]+)>/){
				$drives->{$working}{'model'} = $1;
				$count = ($drives->{$working}{'model'} =~ tr/,//);
				# print "c: $count $row[2]\n";
				if ($count && $count > 1){
					@temp = split(/,\s*/, $drives->{$working}{'model'});
					$drives->{$working}{'vendor'} = $temp[0];
					$drives->{$working}{'model'} = $temp[1];
					$drives->{$working}{'rev'} = $temp[2];
				}
				if ($show{'optical'}){
					if (/\bDVD\b/){
						$drives->{$working}{'dvd'} = 1;
					}
					if (/\bRW\b/){
						$drives->{$working}{'cdrw'} = 1;
						$drives->{$working}{'dvdr'} = 1 if $drives->{$working}{'dvd'};
					}
					if (/\bDVD[-]?RAM\b/){
						$drives->{$working}{'cdr'} = 1;
						$drives->{$working}{'dvdram'} = 1;
					}
				}
			}
			if ($show{'optical'}){
				# print "$row[1]\n";
				if (($row[1] =~ tr/,//) > 1){
					@temp = split(/,\s*/, $row[1]);
					$drives->{$working}{'speed'} = $temp[2];
				}
			}
		}
	}
	main::log_data('dump','%$drives',$drives) if $b_log;
	# print Data::Dumper::Dumper $drives;
	eval $end if $b_log;
	return $drives;
}

sub drive_data_linux {
	eval $start if $b_log;
	my (@data,@info,@rows);
	my $drives = {};
	@data = main::globber('/dev/dvd* /dev/cdr* /dev/scd* /dev/sr* /dev/fd[0-9]');
	# Newer kernel is NOT linking all optical drives. Some, but not all.
	# Get the actual disk dev location, first try default which is easier to run, 
	# need to preserve line breaks
	foreach (@data){
		my $working = readlink($_);
		$working = ($working) ? $working: $_;
		next if $working =~ /random/;
		# possible fix: puppy has these in /mnt not /dev they say
		$working =~ s/\/(dev|media|mnt)\///;
		$_ =~ s/\/(dev|media|mnt)\///;
		if  (!defined $drives->{$working}){
			my @temp = ($_ ne $working) ? ($_) : ();
			$drives->{$working}{'links'} = \@temp;
			$drives->{$working}{'type'} = ($working =~ /^fd/) ? 'floppy' : 'optical' ;
		}
 		else {
 			push(@{$drives->{$working}{'links'}}, $_) if $_ ne $working;
 		}
		# print "$working\n";
	}
	if ($show{'optical'} && -e '/proc/sys/dev/cdrom/info'){
		@info = main::reader('/proc/sys/dev/cdrom/info','strip');
	}
	# print join('; ', @data), "\n";
	foreach my $key (keys %$drives){
		next if $drives->{$key}{'type'} eq 'floppy';
		my $device = "/sys/block/$key/device";
		if (-d $device){
			if (-r "$device/vendor"){
				$drives->{$key}{'vendor'} = main::reader("$device/vendor",'',0);
				$drives->{$key}{'vendor'} = main::clean($drives->{$key}{'vendor'});
				$drives->{$key}{'state'} = main::reader("$device/state",'',0);
				$drives->{$key}{'model'} = main::reader("$device/model",'',0);
				$drives->{$key}{'model'} = main::clean($drives->{$key}{'model'});
				$drives->{$key}{'rev'} = main::reader("$device/rev",'',0);
			}
		}
		elsif (-r "/proc/ide/$key/model"){
			$drives->{$key}{'vendor'} = main::reader("/proc/ide/$key/model",'',0);
			$drives->{$key}{'vendor'} = main::clean($drives->{$key}{'vendor'});
		}
		if ($show{'optical'} && @info){
			my $index = 0;
			foreach my $item (@info){
				next if $item =~ /^\s*$/;
				my @split = split(/\s+/, $item);
				if ($item =~ /^drive name:/){
					foreach my $id (@split){
						last if ($id eq $key);
						$index++;
					}
					last if !$index; # index will be > 0 if it was found
				}
				elsif ($item =~/^drive speed:/){
					$drives->{$key}{'speed'} = $split[$index];
				}
				elsif ($item =~/^Can read multisession:/){
					$drives->{$key}{'multisession'}=$split[$index+1];
				}
				elsif ($item =~/^Can read MCN:/){
					$drives->{$key}{'mcn'}=$split[$index+1];
				}
				elsif ($item =~/^Can play audio:/){
					$drives->{$key}{'audio'}=$split[$index+1];
				}
				elsif ($item =~/^Can write CD-R:/){
					$drives->{$key}{'cdr'}=$split[$index+1];
				}
				elsif ($item =~/^Can write CD-RW:/){
					$drives->{$key}{'cdrw'}=$split[$index+1];
				}
				elsif ($item =~/^Can read DVD:/){
					$drives->{$key}{'dvd'}=$split[$index+1];
				}
				elsif ($item =~/^Can write DVD-R:/){
					$drives->{$key}{'dvdr'}=$split[$index+1];
				}
				elsif ($item =~/^Can write DVD-RAM:/){
					$drives->{$key}{'dvdram'}=$split[$index+1];
				}
			}
		}
	}
	main::log_data('dump','%$drives',$drives) if $b_log;
	# print Data::Dumper::Dumper $drives;
	eval $end if $b_log;
	return $drives;
}
}

## PartitionItem
{
# these will be globally accessible via PartitionItem::filters()
my ($fs_exclude,$fs_skip,$part_filter);