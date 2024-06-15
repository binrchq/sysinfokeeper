package DmidecodeData;

# Note, all actual tests have already been run in check_tools so if we
# got here, we're good. 
sub set {
	eval $start if $b_log;
	${$_[0]} = 1; # set check boolean by reference
	if ($fake{'dmidecode'} || $alerts{'dmidecode'}->{'action'} eq 'use'){
		generate_data();
	}
	eval $end if $b_log;
}

sub generate_data {
	eval $start if $b_log;
	my ($content,@data,@working,$type,$handle);
	if ($fake{'dmidecode'}){
		my $file;
		# $file = "$fake_data_dir/dmidecode/pci-freebsd-8.2-2";
		# $file = "$fake_data_dir/dmidecode/dmidecode-loki-1.txt";
		# $file = "$fake_data_dir/dmidecode/dmidecode-t41-1.txt";
		# $file = "$fake_data_dir/dmidecode/dmidecode-mint-20180106.txt";
		# $file = "$fake_data_dir/dmidecode/dmidecode-vmware-ram-1.txt";
		# $file = "$fake_data_dir/dmidecode/dmidecode-tyan-4408.txt";
		# $file = "$fake_data_dir/ram/dmidecode-speed-configured-1.txt";
		# $file = "$fake_data_dir/ram/dmidecode-speed-configured-2.txt";
		# $file = "$fake_data_dir/ram/00srv-dmidecode-mushkin-1.txt";
		# $file = "$fake_data_dir/dmidecode/dmidecode-slots-pcix-pcie-1.txt";
		# $file = "$fake_data_dir/dmidecode/dmidecode-Microknopix-pci-vga-types-5-6-16-17.txt";
		# open(my $fh, '<', $file) or die "can't open $file: $!";
		# chomp(@data = <$fh>);
	}
	else {
		$content = qx($alerts{'dmidecode'}->{'path'} 2>/dev/null);
		@data = split('\n', $content);
	}
	# we don't need the opener lines of dmidecode output
	# but we do want to preserve the indentation. Empty lines
	# won't matter, they will be skipped, so no need to handle them.
	# some dmidecodes do not use empty line separators
	splice(@data, 0, 5) if @data;
	my $j = 0;
	my $b_skip = 1;
	foreach (@data){
		if (!/^Hand/){
			next if $b_skip;
			if (/^[^\s]/){
				$_ = lc($_);
				$_ =~ s/\s(information)//;
				push(@working, $_);
			}
			elsif (/^\t/){
				$_ =~ s/^\t\t/~/;
				$_ =~ s/^\t|\s+$//g;
				push(@working, $_);
			}
		}
		elsif (/^Handle\s(0x[0-9A-Fa-f]+).*DMI\stype\s([0-9]+),.*/){
			$j = scalar @dmi;
			$handle = hex($1);
			$type = $2;
			$use{'slot-tool'} = 1 if $type && $type == 9;
			$b_skip = ($type > 126) ? 1 : 0;
			next if $b_skip;
			# we don't need 32, system boot, or 127, end of table
			if (@working){
				if ($working[0] != 32 && $working[0] < 127){
					$dmi[$j] = (
					[@working],
					);
				}
			}
			@working = ($type,$handle);
		}
	}
	if (@working && $working[0] != 32 && $working[0] != 127){
		$j = scalar @dmi;
		$dmi[$j] = \@working;
	}
	# last by not least, sort it by dmi type, now we don't have to worry
	# about random dmi type ordering in the data, which happens. Also sort 
	# by handle, as secondary sort.
	@dmi = sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } @dmi;
	main::log_data('dump','@dmi',\@dmi) if $b_log;
	print Data::Dumper::Dumper \@dmi if $dbg[2];
	eval $end if $b_log;
}
}

# args: 0: driver; 1: modules, comma separated, return only modules 
# which do not equal the driver string itself. Sometimes the module
# name is different from the driver name, even though it's the same thing.
sub get_driver_modules {
	eval $start if $b_log;
	my ($driver,$modules) = @_;
	return if !$modules;
	my @mods = split(/,\s+/, $modules);
	if ($driver){
		@mods = grep {!/^$driver$/} @mods;
		my $join = (length(join(',', @mods)) > 40) ? ', ' : ',';
		$modules = join($join, @mods);
	}
	log_data('data','$modules',$modules) if $b_log;
	eval $end if $b_log;
	return $modules;
}

## GlabelData: public methods: get()
# Used to partitions, swap, RAID ZFS gptid path standard name, like ada0p1
{