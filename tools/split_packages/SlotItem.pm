package SlotItem;
my ($sys_slots);

sub get {
	eval $start if $b_log;
	my ($data,$key1,$val1);
	my $rows = [];
	my $num = 0;
	if ($fake{'dmidecode'} || ($alerts{'dmidecode'}->{'action'} eq 'use' && 
	 (!%risc || $use{'slot-tool'}))){
		if ($b_admin && -e '/sys/devices/pci0000:00'){
			slot_data_sys();
		}
		$data = slot_data_dmi();
		slot_output($rows,$data) if @$data;
		if (!@$rows){
			my $key = 'Message';
			push(@$rows, {
			main::key($num++,0,1,$key) => main::message('pci-slot-data','')
			});
		}
	}
	elsif (%risc && !$use{'slot-tool'}){
		$key1 = 'Message';
		$val1 = main::message('risc-pci',$risc{'id'});
		@$rows = ({main::key($num++,0,1,$key1) => $val1});
	}
	elsif ($alerts{'dmidecode'}->{'action'} ne 'use'){
		$key1 = $alerts{'dmidecode'}->{'action'};
		$val1 = $alerts{'dmidecode'}->{'message'};
		$key1 = ucfirst($key1);
		@$rows = ({main::key($num++,0,1,$key1) => $val1});
	}
	eval $end if $b_log;
	return $rows;
}

sub slot_output {
	eval $start if $b_log;
	my ($rows,$data) = @_;
	my $num = 1;
	foreach my $slot_data (@$data){
		next if !$slot_data || ref $slot_data ne 'HASH';
		$num = 1;
		my $j = scalar @$rows;
		$slot_data->{'id'} = 'N/A' if !defined $slot_data->{'id'}; # can be 0
		$slot_data->{'pci'} ||= 'N/A';
		push(@$rows, {
		main::key($num++,1,1,'Slot') => $slot_data->{'id'},
		main::key($num++,0,2,'type') => $slot_data->{'pci'},
		},);
		# PCIe only
		if ($extra > 1 && $slot_data->{'gen'}){
			$rows->[$j]{main::key($num++,0,2,'gen')} = $slot_data->{'gen'};
		}
		if ($slot_data->{'lanes-phys'} && $slot_data->{'lanes-active'} && 
		$slot_data->{'lanes-phys'} ne $slot_data->{'lanes-active'}){
			$rows->[$j]{main::key($num++,1,2,'lanes')} = '';
			$rows->[$j]{main::key($num++,0,3,'phys')} = $slot_data->{'lanes-phys'};
			$rows->[$j]{main::key($num++,0,3,'active')} = $slot_data->{'lanes-active'};
		}
		elsif ($slot_data->{'lanes-phys'}){
			$rows->[$j]{main::key($num++,0,2,'lanes')} = $slot_data->{'lanes-phys'};
		}
		# Non PCIe only
		if ($extra > 1 && $slot_data->{'bits'}){
			$rows->[$j]{main::key($num++,0,2,'bits')} = $slot_data->{'bits'};
		}
		# PCI-X and PCI only
		if ($extra > 1 && $slot_data->{'mhz'}){
			$rows->[$j]{main::key($num++,0,2,'MHz')} = $slot_data->{'mhz'};
		}
		$rows->[$j]{main::key($num++,0,2,'status')} = $slot_data->{'usage'};
		if ($slot_data->{'extra'}){
			$rows->[$j]{main::key($num++,0,2,'info')} = join(', ', @{$slot_data->{'extra'}});
		}
		if ($extra > 1){
			$slot_data->{'length'} ||= 'N/A';
			$rows->[$j]{main::key($num++,0,2,'length')} = $slot_data->{'length'};
			if ($slot_data->{'cpu'}){
				$rows->[$j]{main::key($num++,0,2,'cpu')} = $slot_data->{'cpu'};
			}
			if ($slot_data->{'volts'}){
				$rows->[$j]{main::key($num++,0,2,'volts')} = $slot_data->{'volts'};
			}
		}
		if ($extra > 0){
			$slot_data->{'bus_address'} ||= 'N/A';
			$rows->[$j]{main::key($num++,1,2,'bus-ID')} = $slot_data->{'bus_address'};
			if ($b_admin && $slot_data->{'children'}){
				children_output($rows,$j,\$num,$slot_data->{'children'},3);
			}
		}
	}
	eval $end if $b_log;
}
sub children_output {
	my ($rows,$j,$num,$children,$ind) = @_;
	my $cnt = 0;
	$rows->[$j]{main::key($$num++,1,$ind,'children')} = '';
	$ind++;
	foreach my $id (sort keys %{$children}){
		$cnt++;
		$rows->[$j]{main::key($$num++,1,$ind,$cnt)} = $id;
		if ($children->{$id}{'class-id'} && $children->{$id}{'class-id-sub'}){
			my $class = $children->{$id}{'class-id'} . $children->{$id}{'class-id-sub'};
			$rows->[$j]{main::key($$num++,0,($ind + 1),'class-ID')} = $class;
			if ($children->{$id}{'class'}){
				$rows->[$j]{main::key($$num++,0,($ind + 1),'type')} = $children->{$id}{'class'};
			}
		}
		if ($children->{$id}{'children'}){
			children_output($rows,$j,$num,$children->{$id}{'children'},$ind + 1);
		}
	}
}

sub slot_data_dmi {
	eval $start if $b_log;
	my $i = 0;
	my $slots = [];
	foreach my $slot_data (@dmi){
		next if $slot_data->[0] != 9;
		my (%data,@extra);
		# skip first two row, we don't need that data
		foreach my $item (@$slot_data[2 .. $#$slot_data]){
			if ($item !~ /^~/){ # skip the indented rows
				my @value = split(/:\s+/, $item, 2);
				if ($value[0] eq 'Type'){
					$data{'type'} = $value[1];
				}
				if ($value[0] eq 'Designation'){
					$data{'designation'} = $value[1];
				}
				if ($value[0] eq 'Current Usage'){
					$data{'usage'} = lc($value[1]);
				}
				if ($value[0] eq 'ID'){
					$data{'id'} = $value[1];
				}
				if ($value[0] eq 'Length'){
					$data{'length'} = lc($value[1]);
				}
				if ($value[0] eq 'Bus Address'){
					$value[1] =~ s/^0000://;
					$data{'bus_address'} = $value[1];
					if ($b_admin && $sys_slots){
						$data{'children'} = slot_children($data{'bus_address'},$sys_slots);
					}
				}
			}
			elsif ($item =~ /^~([\d.]+)[\s-]?V is provided/){
				$data{'volts'} = $1;
			}
		}
		if ($data{'type'} eq 'Other' && $data{'designation'}){
			$data{'type'} = $data{'designation'};
			undef $data{'designation'};
		}
		foreach my $string (($data{'type'},$data{'designation'})){
			next if !$string;
			print "st: $string\n" if $dbg[48];
			$string =~ s/(PCI[\s_-]?Express|Pci[_-]?e)/PCIe /ig;
			$string =~ s/PCI[\s_-]?X/PCIX /ig;
			$string =~ s/Mini[\s_-]?PCI/MiniPCI /ig;
			$string =~ s/Media[\s_-]?Card/MediaCard/ig;
			$string =~ s/Express[\s_-]?Card/ExpressCard/ig;
			$string =~ s/Card[\s_-]?Bus/CardBus/ig;
			$string =~ s/PCMCIA/PCMCIA /ig;
			if (!$data{'pci'} && $string =~ /(AGP|ISA|MiniPCI|PCIe|PCIX|PCMCIA|PCI)/){
				$data{'pci'} = $1;
				# print "pci: $data{'pci'}\n";
			}
			if ($string =~ /(MiniPCI|PCMCIA)/){
				$data{'pci'} = $1;
				# print "pci: $data{'pci'}\n";
			}
			# legacy format: PCIE#3-x8 
			if (!$data{'lanes-phys'} && $string =~ /(^x|#\d+-x)(\d+)/){
				$data{'lanes-phys'} = $2;
			}
			if (!$data{'lanes-active'} && $string =~ /^x\d+ .*? x(\d+)/){
				$data{'lanes-active'} = $1;
			}
			# legacy format, seens with PCI-X/PCIe mobos: PCIX#2-100MHz,  PCIE#3-x8
			if (!defined $data{'id'} && $string =~ /(#|PCI)(\d+)\b/){
				$data{'id'} = $2;
			}
			if (!defined $data{'id'} && $string =~ /SLOT[\s-]?(\d+)\b/i){
				$data{'id'} = $1;
			}
			if ($string =~ s/\bJ-?(\S+)\b//){
				push(@extra,'J' . $1) if ! grep {$_ eq 'J' . $1} @extra;
			}
			if ($string =~ s/\bM\.?2\b//){
				push(@extra,'M.2') if ! grep {$_ eq 'M.2'} @extra;
			}
			if ($string =~ /(ExpressCard|MediaCard|CardBus)/){
				push(@extra,$1) if ! grep {$_ eq $1} @extra;
			}
			if (!$data{'cpu'} && $string =~ s/CPU-?(\d+)\b//){
				$data{'cpu'} = $1;
			}
			if (!$data{'gen'} && $data{'pci'} && $data{'pci'} eq 'PCIe' && 
			$string =~ /PCIe[\s_-]*([\d.]+)/){
				$data{'gen'} = $1 + 0;
			}
			if (!$data{'mhz'} && $data{'pci'} && $string =~ /(\d+)[\s_-]?MHz/){
				$data{'mhz'} = $1;
			}
			if (!$data{'bits'} && $data{'pci'} && $string =~ /\b(\d+)[\s_-]?bit/){
				$data{'bits'} = $1;
			}
			$i++;
		}
		if (!$data{'pci'} && $data{'type'} && 
		$data{'type'} =~ /(ExpressCard|MediaCard|CardBus)/){
			$data{'pci'} = $1;
			@extra = grep {$_ ne $data{'pci'}} @extra;
		}
		$data{'extra'} = [@extra] if @extra;
		push(@$slots,{%data}) if %data;
	}
	print '@$slots: ',  Data::Dumper::Dumper $slots if $dbg[48];
	main::log_data('dump','@$slots final',$slots) if $b_log;
	eval $end if $b_log;
	return $slots;
}

sub slot_data_sys {
	eval $start if $b_log;
	my $path = '/sys/devices/pci0000:*/00*';
	my @data = main::globber($path);
	my ($full,$id);
	foreach $full (@data){
		$id = $full;
		$id =~ s/^.*\/\S+:([0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]+)$/$1/;
		$sys_slots->{$id} = slot_data_recursive($full);
	}
	print 'sys_slots: ', Data::Dumper::Dumper $sys_slots if $dbg[49];
	main::log_data('dump','$sys_slots',$sys_slots) if $b_log;
	eval $end if $b_log;
}

sub slot_data_recursive {
	eval $start if $b_log;
	my $path = shift @_;
	my $info = {};
	my $id = $path;
	$id =~ s/^.*\/\S+:(\S{2}:\S{2}\.\S+)$/$1/;
	my ($content,$id2,@files);
	# @files = main::globber("$full/{class,current_link_speed,current_link_width,max_link_speed,max_link_width,00*}");
	if (-e "$path/class" && ($content = main::reader("$path/class",'strip',0))){
		if ($content =~ /^0x(\S{2})(\S{2})/){
			$info->{'class-id'} = $1;
			$info->{'class-id-sub'} = $2;
			$info->{'class'} = DeviceData::pci_class($1);
			if ($info->{'class-id'} eq '06'){
				my @files = main::globber("$path/00*:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f].[0-9a-f]");
				foreach my $item (@files){
					$id = $item;
					$id =~ s/^.*\/[0-9a-f]+:([0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]+)$/$1/;
					$info->{'children'}{$id} = slot_data_recursive($item);
				}
			}
		}
	}
	if (-e "$path/current_link_speed" && 
	($content = main::reader("$path/current_link_speed",'strip',0))){
		$content =~ s/\sPCIe//i;
		$info->{'current-link-speed'} = main::clean_dmi($content);
	}
	if (-e "$path/current_link_width" && 
	($content = main::reader("$path/current_link_width",'strip',0))){
		$info->{'current-link-width'} = $content;
	}
	eval $end if $b_log;
	return $info;
}

sub slot_children {
	eval $start if $b_log;
	my ($bus_id,$slots) = @_;
	my $children = slot_children_recursive($bus_id,$slots);
	# $children->{'0a:00.0'}{'children'} = {'3423' => {
	# 'class' => 'test','class-id' => '05','class-id-sub' => '10'}};
	print $bus_id, ' children: ', Data::Dumper::Dumper $children if $dbg[49];
	main::log_data('dump','$children',$children) if $b_log;
	eval $end if $b_log;
	return $children;
}

sub slot_children_recursive {
	my ($bus_id,$slots) = @_;
	my $children;
	foreach my $key (keys %{$slots}){
		if ($slots->{$bus_id}){
			$children = $slots->{$bus_id}{'children'} if $slots->{$bus_id}{'children'};
			last;
		}
		elsif ($slots->{$key}{'children'}){
			slot_children_recursive($bus_id,$slots->{$key}{'children'});
		}
	}
	return $children;
}
}

## SwapItem 
{