package PowerData;
my $power = {};

# args: 0: $power by ref
sub get {
	eval $start if $b_log;
	sys_data();
	eval $end if $b_log;
	return $power;
}

sub sys_data {
	eval $start if $b_log;
	# Some systems also report > 1 wakeup events per wakeup with 
	# /sys/power/wakeup_count, thus, we are using /sys/power/suspend_stats/success 
	# which does not appear to have that issue.  There is more info in suspend_stats
	# which we might think of using, particularly fail events, which can be useful.
	# this increments on suspend, but you can't see it until wake, numbers work.
	# note: seen android instance where reading file wakeup_count hangs endlessly.
	my %files = ('suspend-resumes' => '/sys/power/suspend_stats/success');
	if ($extra > 2){
		$files{'hibernate'} = '/sys/power/disk';
		$files{'hibernate-image-size'} = '/sys/power/image_size';
		$files{'suspend'} = '/sys/power/mem_sleep';
		$files{'suspend-fails'} = '/sys/power/suspend_stats/fail';
		$files{'states-avail'} = '/sys/power/state';
	}
	foreach (sort keys %files){
		if (-r $files{$_}){
			$power->{$_} = main::reader($files{$_}, 'strip', 0);
			if ($_ eq 'states-avail'){
				$power->{$_} =~ s/\s+/,/g if $power->{$_};
			}
			# seen: s2idle [deep] OR [s2idle] deep OR s2idle shallow [deep]
			elsif ($_ eq 'hibernate' || $_ eq 'suspend'){
				# [item] is currently selected/active option
				if ($power->{$_}){
					if ($power->{$_} =~ /\[([^\]]+)\]/){
						$power->{$_ . '-active'} = $1;
						$power->{$_} =~ s/\[$1\]//;
						$power->{$_} =~ s/^\s+|\s+$//g;
					}
					# some of these can get pretty long, so handle with make_list_value
					if ($power->{$_}){
						main::make_list_value([split(/\s+/,$power->{$_})],\$power->{$_},',');
						$power->{$_ . '-avail'} = $power->{$_};
					}
				}
			}
			# size is in bytes
			elsif ($_ eq 'hibernate-image-size'){
				$power->{$_} = main::get_size(($power->{$_}/1024),'string') if defined $power->{$_};
			}
		}
	}
	print 'power: ', Data::Dumper::Dumper $power if $dbg[58];
	main::log_data('dump','$power',$power) if $b_log;
	eval $end if $b_log;
}
}

# ProgramData 
# public methods: 
# full(): returns (print name, version nu, [full version data output]).
# values(): returns program values array
# version(): returns program version number
{