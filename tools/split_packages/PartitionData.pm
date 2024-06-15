package PartitionData;

sub set {
	my ($type) = @_;
	$loaded{'partition-data'} = 1;
	if (my $file = $system_files{'proc-partitions'}){
		proc_data($file);
	}
}

# args: 0: partition name, without /dev, like sda1, sde
sub get {
	eval $start if $b_log;
	my $item = $_[0];
	return if !@proc_partitions;
	my $result;
	foreach my $device (@proc_partitions){
		if ($device->[3] eq $item){
			$result = $device;
			last;
		}
	}
	eval $start if $b_log;
	return ($result) ? $result : [];
}

sub proc_data {
	eval $start if $b_log;
	my $file = $_[0];
	if ($fake{'partitions'}){
		# $file = "$fake_data_dir/block-devices/proc-partitions/proc-partitions-1.txt";
	}
	my @parts = main::reader($file,'strip');
	# print Data::Dumper::Dumper \@parts;
	shift @parts if @parts; # get rid of headers
	for (@parts){
		my @temp = split(/\s+/, $_);
		next if !defined $temp[2];
		push (@proc_partitions,[$temp[0],$temp[1],$temp[2],$temp[3]]);
	}
	eval $end if $b_log;
}
}

# args: 0: pci device string; 1: pci cleaned subsystem string
sub get_pci_vendor {
	eval $start if $b_log;
	my ($device, $subsystem) = @_;
	return if !$subsystem;
	my ($vendor,$sep) = ('','');
	# get rid of any [({ type characters that will make regex fail
	# and similar matches show as non-match
	my @data = split(/\s+/, clean_regex($subsystem));
	foreach my $word (@data){
		# AMD Tahiti PRO [Radeon HD 7950/8950 OEM / R9 280]
		# PC Partner Limited / Sapphire Technology Tahiti PRO [Radeon HD 7950/8950 OEM / R9 280]
		# $word =~ s/(\+|\$|\?|\^|\*)/\\$1/g;
		if (length($word) == 1 || $device !~ m|\b\Q$word\E\b|i){
			$vendor .= $sep . $word;
			$sep = ' ';
		}
		else {
			last;
		}
	}
	# just in case we had a standalone last character after done
	$vendor =~ s| [/\(\[\{a\.,-]$|| if $vendor;
	eval $end if $b_log;
	return $vendor;
}

# $rows, $num by ref.
sub get_pcie_data {
	eval $start if $b_log;
	my ($bus_id,$j,$rows,$num,$type) = @_;
	$type ||= '';
	# see also /sys/class/drm/
	my $path_start = '/sys/bus/pci/devices/0000:';
	return if !$bus_id || ! -d $path_start . $bus_id;
	$path_start .= $bus_id;
	my $path = $path_start . '/{max_link_width,current_link_width,max_link_speed';
	$path .= ',current_link_speed}';
	my @files = globber($path);
	if ($type eq 'gpu'){
		$path = $path_start . '/0000*/0000*/{mem_info_vram_used,mem_info_vram_total}';
		push(@files,globber($path));
	}
	# print @files,"\n";
	return if !@files;
	my (%data,$name);
	my %gen = (
	'2.5 GT/s' => 1,
	'5 GT/s' => 2,
	'8 GT/s' => 3,
	'16 GT/s' => 4,
	'32 GT/s' => 5,
	'64 GT/s' => 6,
	);
	foreach (@files){
		if (-r $_){
			$name = $_;
			$name =~ s|^/.*/||;
			$data{$name} = reader($_,'strip',0);
			if ($name eq 'max_link_speed' || $name eq 'current_link_speed'){
				$data{$name} =~ s/\.0\b| PCIe$//g; # trim .0 off in 5.0, 8.0
			}
		}
	}
	# print Data::Dumper::Dumper \%data;
	# Maximum PCIe Bandwidth = SPEED * WIDTH * (1 - ENCODING) - 1Gb/s.
	if ($data{'current_link_speed'} && $data{'current_link_width'}){
		$$rows[$j]->{key($$num++,1,2,'pcie')} = '';
		if ($b_admin && $gen{$data{'current_link_speed'}}){
			$$rows[$j]{key($$num++,0,3,'gen')} = $gen{$data{'current_link_speed'}};
		}
		$$rows[$j]{key($$num++,0,3,'speed')} = $data{'current_link_speed'};
		$$rows[$j]->{key($$num++,0,3,'lanes')} = $data{'current_link_width'};
		if ($b_admin && (($data{'max_link_speed'} && 
		 $data{'max_link_speed'} ne $data{'current_link_speed'}) || 
		 ($data{'max_link_width'} && 
		 $data{'max_link_width'} ne $data{'current_link_width'}))){
			$$rows[$j]->{key($$num++,1,3,'link-max')} = '';
			if ($data{'max_link_speed'} && 
			 $data{'max_link_speed'} ne $data{'current_link_speed'}){
				$$rows[$j]{key($$num++,0,4,'gen')} = $gen{$data{'max_link_speed'}};
				$$rows[$j]->{key($$num++,0,4,'speed')} = $data{'max_link_speed'};
			}
			if ($data{'max_link_width'} && 
			 $data{'max_link_width'} ne $data{'current_link_width'}){
				$$rows[$j]->{key($$num++,0,4,'lanes')} = $data{'max_link_width'};
			}
		}
	}
	if ($type eq 'gpu' && $data{'mem_info_vram_used'} && $data{'mem_info_vram_total'}){
		$$rows[$j]->{key($$num++,1,2,'vram')} = '';
		$$rows[$j]->{key($$num++,0,3,'total')} = get_size($data{'mem_info_vram_total'}/1024,'string');
		my $used = get_size($data{'mem_info_vram_used'}/1024,'string');
		$used .= ' (' . sprintf('%0.1f',($data{'mem_info_vram_used'}/$data{'mem_info_vram_total'}*100)) . '%)';
		$$rows[$j]->{key($$num++,0,3,'used')} = $used;
		
	}
	eval $end if $b_log;
}

## PowerData: public method: get()
# No BSD support currently. Test by !$bsd_type. Should any BSD data source 
# appear, make bsd_data() and add $bsd_type switch here, remove from caller.
{