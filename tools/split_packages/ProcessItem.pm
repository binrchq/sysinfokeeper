package ProcessItem;
# header:
# 0: CMD
# 1: PID
# 2: %CPU
# 3: %MEM
# 4: RSS
my $header;

sub get {
	eval $start if $b_log;
	my $num = 0;
	my $rows = [];
	if (@ps_aux){
		$header = $ps_data{'header'}; # will always be set if @ps_aux
		if ($show{'ps-cpu'}){
			cpu_processes($rows);
		}
		if ($show{'ps-mem'}){
			mem_processes($rows);
		}
	}
	else {
		my $key = 'Message';
		push(@$rows, {
		main::key($num++,0,1,$key) => main::message('ps-data-null','')
		});
	}
	eval $end if $b_log;
	return $rows;
}

sub cpu_processes {
	eval $start if $b_log;
	my $rows = $_[0];
	my ($j,$num,$cpu,$cpu_mem,$mem,$pid) = (0,0,'','','','');
	my (@ps_rows);
	my $count = ($b_irc)? 5 : $ps_count;
	if (defined $header->[2]){
		@ps_rows = sort { 
		my @a = split(/\s+/, $a); 
		my @b = split(/\s+/, $b); 
		$b[$header->[2]] <=> $a[$header->[2]] 
		} @ps_aux;
	}
	else {
		@ps_rows = @ps_aux;
	}
	@ps_rows = splice(@ps_rows,0,$count);
	$j = scalar @ps_rows;
	# if there's a count limit, for irc, etc, only use that much of the data
	my $throttled = throttled($ps_count,$count);
	push(@$rows,{
	main::key($num++,1,1,'CPU top') => "$count$throttled" . ' of ' . scalar @ps_aux
	});
	my $i = 1;
	foreach (@ps_rows){
		$num = 1;
		$j = scalar @$rows;
		my @row = split(/\s+/, $_);
		my $command = process_starter(
			scalar @row, 
			$row[$header->[0]],
			$row[$header->[0] + 1]
		);
		$cpu = (defined $header->[2]) ? $row[$header->[2]] . '%': 'N/A';
		push(@$rows,{
		main::key($num++,1,2,$i++) => '',
		main::key($num++,0,3,'cpu') => $cpu,
		main::key($num++,1,3,'command') => $command->[0],
		});
		if ($command->[1]){
			$rows->[$j]{main::key($num++,0,4,'started-by')} = $command->[1];
		}
		$pid = (defined $header->[1])? $row[$header->[1]] : 'N/A';
		$rows->[$j]{main::key($num++,0,3,'pid')} = $pid;
		if ($extra > 0 && defined $header->[4]){
			my $decimals = ($row[$header->[4]]/1024 > 10) ? 1 : 2;
			$mem = (defined $row[$header->[4]]) ? sprintf("%.${decimals}f", $row[$header->[4]]/1024) . ' MiB' : 'N/A';
			$mem .= ' (' . $row[$header->[3]] . '%)';
			$rows->[$j]{main::key($num++,0,3,'mem')} = $mem;
		}
		# print Data::Dumper::Dumper \@processes, "i: $i; j: $j ";
	}
	eval $end if $b_log;
}

sub mem_processes {
	eval $start if $b_log;
	my $rows = $_[0];
	my ($j,$num,$cpu,$cpu_mem,$mem,$pid) = (0,0,'','','','');
	my (@data,$memory,@ps_rows);
	my $count = ($b_irc)? 5 : $ps_count;
	if (defined $header->[4]){
		@ps_rows = sort { 
		my @a = split(/\s+/, $a); 
		my @b = split(/\s+/, $b); 
		$b[$header->[4]] <=> $a[$header->[4]] 
		} @ps_aux;
	}
	else {
		@ps_rows = @ps_aux;
	}
	@ps_rows = splice(@ps_rows,0,$count);
	# print Data::Dumper::Dumper \@rows;
	if (!$loaded{'memory'}){
		my $row = {};
		main::MemoryData::row('process',$row,\$num,1);
		push(@$rows,$row);
		$num = 0;
	}
	$j = scalar @$rows;
	my $throttled = throttled($ps_count,$count);
	push(@$rows, {
	main::key($num++,1,1,'Memory top') => "$count$throttled" . ' of ' . scalar @ps_aux
	});
	my $i = 1;
	foreach (@ps_rows){
		$num = 1;
		$j = scalar @$rows;
		my @row = split(/\s+/, $_);
		if (defined $header->[4]){
			my $decimals = ($row[$header->[4]]/1024 > 10) ? 1 : 2;
			$mem = (main::is_int($row[$header->[4]])) ? 
				sprintf("%.${decimals}f", $row[$header->[4]]/1024) . ' MiB' : 'N/A';
			$mem .= " (" . $row[$header->[3]] . "%)"; 
		}
		else {
			$mem = 'N/A';
		}
		my $command = process_starter(scalar @row, $row[$header->[0]],$row[$header->[0] + 1]);
		push(@$rows,{
		main::key($num++,1,2,$i++) => '',
		main::key($num++,0,3,'mem') => $mem,
		main::key($num++,1,3,'command') => $command->[0],
		});
		if ($command->[1]){
			$rows->[$j]{main::key($num++,0,4,'started-by')} = $command->[1];
		}
		$pid = (defined $header->[1])? $row[$header->[1]] : 'N/A';
		$rows->[$j]{main::key($num++,0,3,'pid')} = $pid;
		if ($extra > 0 && defined $header->[2]){
			$cpu = $row[$header->[2]] . '%';
			$rows->[$j]{main::key($num++,0,3,'cpu')} = $cpu;
		}
		# print Data::Dumper::Dumper \@processes, "i: $i; j: $j ";
	}
	eval $end if $b_log;
}

sub process_starter {
	my ($count, $row10, $row11) = @_;
	my $return = [];
	# note: [migration/0] would clear with a simple basename
	if ($count > ($header->[0] + 1) && 
	$row11 =~ /^\// && $row11 !~ /^\/(tmp|temp)/){
		$row11 =~ s/^\/.*\///;
		$return->[0] = $row11;
		$row10 =~ s/^\/.*\///;
		$return->[1] = $row10;
	}
	else {
		$row10 =~ s/^\/.*\///;
		$return->[0] = $row10;
		$return->[1] = '';
	}
	return $return;
}

# args: 0: $ps_count; 1: $count
sub throttled {
	return ($_[1] < $_[0]) ? " (throttled from $_[0])" : '';
}
}

## RaidItem
{