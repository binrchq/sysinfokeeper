package SwapItem;

sub get {
	eval $start if $b_log;
	my $rows = [];
	my $num = 0;
	create_output($rows);
	if (!@$rows){
		@$rows = ({main::key($num++,0,1,'Alert') => main::message('swap-data')});
	}
	eval $end if $b_log;
	return $rows;
}

sub create_output {
	eval $start if $b_log;
	my $rows = $_[0];
	my $num = 0;
	my $j = 0;
	my (@rows,$dev,$percent,$raw_size,$size,$used);
	PartitionData::set() if !$bsd_type && !$loaded{'partition-data'};
	DiskDataBSD::set() if $bsd_type && !$loaded{'disk-data-bsd'};
	main::set_mapper() if !$loaded{'mapper'};
	PartitionItem::swap_data() if !$loaded{'set-swap'};
	foreach my $row (@swaps){
		$num = 1;
		$size = ($row->{'size'}) ? main::get_size($row->{'size'},'string') : 'N/A';
		$used = main::get_size($row->{'used'},'string','N/A'); # used can be 0
		$percent = (defined $row->{'percent-used'}) ? ' (' . $row->{'percent-used'} . '%)' : '';
		$dev = ($row->{'swap-type'} eq 'file') ? 'file' : 'dev';
		$row->{'swap-type'} = ($row->{'swap-type'}) ? $row->{'swap-type'} : 'N/A';
		if ($b_admin && !$bsd_type && $j == 0){
			$j = scalar @rows;
			if (defined $row->{'swappiness'} || defined $row->{'cache-pressure'}){
				$rows->[$j]{main::key($num++,1,1,'Kernel')} = '';
				if (defined $row->{'swappiness'}){
					$rows->[$j]{main::key($num++,0,2,'swappiness')} = $row->{'swappiness'};
				}
				if (defined $row->{'cache-pressure'}){
					$rows->[$j]{main::key($num++,0,2,'cache-pressure')} = $row->{'cache-pressure'};
				}
				$row->{'zswap-enabled'} ||= 'N/A';
				$rows->[$j]{main::key($num++,1,2,'zswap')} = $row->{'zswap-enabled'};
				if ($row->{'zswap-enabled'} eq 'yes'){
					if (defined $row->{'zswap-compressor'}){
						$rows->[$j]{main::key($num++,0,1,'compressor')} = $row->{'zswap-compressor'};
					}
					if (defined $row->{'zswap-max-pool-percent'}){
						$rows->[$j]{main::key($num++,0,1,'max-pool')} = $row->{'zswap-max-pool-percent'} . '%';
					}
				}
			}
			else {
				$rows->[$j]{main::key($num++,0,1,'Message')} = main::message('swap-admin');
			}
		}
		$j = scalar @$rows;
		push(@$rows, {
		main::key($num++,1,1,'ID') => $row->{'id'},
		main::key($num++,0,2,'type') => $row->{'swap-type'},
		});
		# not used for swap as far as I know
		if ($b_admin && $row->{'raw-size'}){
			# It's an error! permissions or missing tool
			$raw_size = main::get_size($row->{'raw-size'},'string');
			$rows->[$j]{main::key($num++,0,2,'raw-size')} = $raw_size;
		}
		# not used for swap as far as I know
		if ($b_admin && $row->{'raw-available'} && $size ne 'N/A'){
			$size .=  ' (' . $row->{'raw-available'} . '%)';
		}
		$rows->[$j]{main::key($num++,0,2,'size')} = $size;
		$rows->[$j]{main::key($num++,0,2,'used')} = $used . $percent;
		# not used for swap as far as I know
		if ($b_admin && $row->{'block-size'}){
			$rows->[$j]{main::key($num++,0,2,'block-size')} = $row->{'block-size'} . ' B';;
			#$rows->[$j]{main::key($num++,0,2,'physical')} = $row->{'block-size'} . ' B';
			#$rows->[$j]{main::key($num++,0,2,'logical')} = $row->{'block-logical'} . ' B';
		}
		if ($extra > 1 && defined $row->{'priority'}){
			$rows->[$j]{main::key($num++,0,2,'priority')} = $row->{'priority'};
		}
		if ($b_admin && $row->{'swap-type'} eq 'zram'){
			if ($row->{'zram-comp'}){
				$rows->[$j]{main::key($num++,1,2,'comp')} = $row->{'zram-comp'};
				if ($row->{'zram-comp-avail'}){
					$rows->[$j]{main::key($num++,0,3,'avail')} = $row->{'zram-comp-avail'};
				}
			}
			if ($row->{'zram-max-comp-streams'}){
				$rows->[$j]{main::key($num++,0,3,'max-streams')} = $row->{'zram-max-comp-streams'};
			}
		}
		if ($row->{'mount'} && $use{'filter'}){
			$row->{'mount'} =~ s|/home/[^/]+/(.*)|/home/$filter_string/$1|;
		}
		$rows->[$j]{main::key($num++,1,2,$dev)} = ($row->{'mount'}) ? $row->{'mount'} : 'N/A';
		if ($b_admin && $row->{'maj-min'}){
			$rows->[$j]{main::key($num++,0,3,'maj-min')} = $row->{'maj-min'};
		}
		if ($extra > 0 && $row->{'dev-mapped'}){
			$rows->[$j]{main::key($num++,0,3,'mapped')} = $row->{'dev-mapped'};
		}
		if ($show{'label'} && ($row->{'label'} || $row->{'swap-type'} eq 'partition')){
			if ($use{'filter-label'}){
				$row->{'label'} = main::filter_partition('part', $row->{'label'}, '');
			}
			$row->{'label'} ||= 'N/A';
			$rows->[$j]{main::key($num++,0,2,'label')} = $row->{'label'};
		}
		if ($show{'uuid'} && ($row->{'uuid'} || $row->{'swap-type'} eq 'partition')){
			if ($use{'filter-uuid'}){
				$row->{'uuid'} = main::filter_partition('part', $row->{'uuid'}, '');
			}
			$row->{'uuid'} ||= 'N/A';
			$rows->[$j]{main::key($num++,0,2,'uuid')} = $row->{'uuid'};
		}
	}
	eval $end if $b_log;
}
}

## UnmountedItem
{