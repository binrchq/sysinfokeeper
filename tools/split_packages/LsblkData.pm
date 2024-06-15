package LsblkData;

# args: 0: partition name
sub get {
	eval $start if $b_log;
	my $item = $_[0];
	return if !@lsblk;
	my $result;
	foreach my $device (@lsblk){
		if ($device->{'name'} eq $item){
			$result = $device;
			last;
		}
	}
	eval $start if $b_log;
	return ($result) ? $result : {};
}

sub set {
	eval $start if $b_log;
	$loaded{'lsblk'} = 1;
	if ($alerts{'lsblk'} && $alerts{'lsblk'}->{'path'}){
		# check to see if lsblk removes : - separators from accepted input syntax
		my $cmd = $alerts{'lsblk'}->{'path'} . ' -bP --output NAME,TYPE,RM,FSTYPE,';
		$cmd .= 'SIZE,LABEL,UUID,SERIAL,MOUNTPOINT,PHY-SEC,LOG-SEC,PARTFLAGS,';
		$cmd .= 'MAJ:MIN,PKNAME 2>/dev/null';
		print "cmd: $cmd\n" if $dbg[32];
		my @working = main::grabber($cmd);
		print Data::Dumper::Dumper \@working if $dbg[32];
		# note: lsblk 2.37 changeed - and : to _ in the output.
		my $pattern = 'NAME="([^"]*)"\s+TYPE="([^"]*)"\s+RM="([^"]*)"\s+';
		$pattern .= 'FSTYPE="([^"]*)"\s+SIZE="([^"]*)"\s+LABEL="([^"]*)"\s+';
		$pattern .= 'UUID="([^"]*)"\s+SERIAL="([^"]*)"\s+MOUNTPOINT="([^"]*)"\s+';
		$pattern .= 'PHY[_-]SEC="([^"]*)"\s+LOG[_-]SEC="([^"]*)"\s+';
		$pattern .= 'PARTFLAGS="([^"]*)"\s+MAJ[:_-]MIN="([^"]*)"\s+PKNAME="([^"]*)"';
		foreach (@working){
			if (/$pattern/){
				my $size = ($5) ? $5/1024: 0;
				# some versions of lsblk do not return serial, fs, uuid, or label
				push(@lsblk, {
				'name' => $1, 
				'type' => $2,
				'rm' => $3, 
				'fs' => $4, 
				'size' => $size,
				'label' => $6,
				'uuid' => $7,
				'serial' => $8,
				'mount' => $9,
				'block-physical' => $10,
				'block-logical' => $11,
				'partition-flags' => $12,
				'maj-min' => $13,
				'parent' => $14,
				});
				# must be below assignments!! otherwise the result of the match replaces values
				# note: for bcache and luks, the device that has that fs is the parent!!
				if ($show{'logical'}){
					$use{'logical-lvm'} = 1 if !$use{'logical-lvm'} && $2 && $2 eq 'lvm';
					if (!$use{'logical-general'} && (($4 && 
					($4 eq 'crypto_LUKS' || $4 eq 'bcache')) || 
					($2 && ($2 eq 'dm' && $1 =~ /veracrypt/i) || $2 eq 'crypto' || 
					$2 eq 'mpath' || $2 eq 'multipath'))){
						$use{'logical-general'} = 1;
					}
				}
			}
		}
	}
	print Data::Dumper::Dumper \@lsblk if $dbg[32];
	main::log_data('dump','@lsblk',\@lsblk) if $b_log;
	eval $end if $b_log;
}
}

sub set_mapper {
	eval $start if $b_log;
	$loaded{'mapper'} = 1;
	return if ! -d '/dev/mapper';
	foreach ((globber('/dev/mapper/*'))){
		my ($key,$value) = ($_,Cwd::abs_path("$_"));
		next if !$value;
		$key =~ s|^/.*/||;
		$value =~ s|^/.*/||;
		$mapper{$key} = $value;
	}
	%dmmapper = reverse %mapper if %mapper;
	eval $end if $b_log;
}

## MemoryData
{