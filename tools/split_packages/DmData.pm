package DmData;
my ($found,@glob);

sub get {
	eval $start if $b_log;
	set_glob();
	$found = {};
	get_dm_lm('dm');
	if (!$found->{'dm'}){
		test_ps_dm()
	}
	get_dm_lm('lm') if !$found->{'dm'};
	print 'dm data: ', Data::Dumper::Dumper $found if $dbg[60];
	main::log_data('dump','display manager: %$found',$found) if $b_log;
	eval $end if $b_log;
	return $found;
}

sub set_glob {
	eval $start if $b_log;
	my $pattern = '';
	if (-d '/run'){
		$pattern .= '/run';
	}
	# in most linux, /var/run is a sym link to /run, so no need to check it twice
	if (-d '/var/run' && ! -l '/var/run'){
		$pattern .= ',' if $pattern;
		$pattern .= '/var/run';
	}
	if (-d '/var/run/rc.d'){
		$pattern .= ',' if $pattern;
		$pattern .= '/var/run/rc.d';
	}
	if ($pattern){
		$pattern = '{' . $pattern . '}/*';
		# for dm.pid type file or dm directory names, like greetd-684.sock
		@glob = main::globber($pattern);
		main::uniq(\@glob) if @glob;
	}
	print '@glob: ', Data::Dumper::Dumper \@glob if $dbg[60];
	main::log_data('dump','dm @glob:',\@glob) if $b_log;
	eval $end if $b_log;
}

# args: 0: dm/lm, first test for dms, then if no dms, test for lms
sub get_dm_lm {
	eval $start if $b_log;
	my $type = $_[0];
	my (@dms,@glob_working,@temp);
	# See: docs/inxi-desktops-wm.txt for Display/login manager info.
	# Guessing on cdm, qingy. pcdm uses vt, PCDM-vt9.pid
	# Add Ly in case they add run file/directory.
	if ($type eq 'dm'){
		@dms = qw(brzdm cdm emptty entranced gdm gdm3 kdm kdm3 kdmctl ldm lemurs 
		lightdm loginx lxdm ly mdm mlogind nodm pcdm qingy sddm slim slimski tdm 
		udm wdm x3dm xdm xdmctl xenodm);
	}
	# greetd frontends: agreety dlm gtkgreet qtgreet tuigreet wlgreet
	else {
		@dms = qw(elogind greetd seatd tbsm);
	}
	# print Data::Dumper::Dumper \@glob;
	# used to test for .pid/lock type file or directory, now just see if the 
	# search name exists in run and call it good since test would always be true
	# if directory existed previously anyway.
	if (@glob){
		my $search = join('|',@dms);
		@glob_working = grep {/\/($search)\b/} @glob;
		if (@glob_working){
			foreach my $item (@glob_working){
				my @id = grep {$item =~ /\/$_\b/} @dms;
				push(@temp,@id) if @id;
			}
			# note: there were issues with duplicated dm's, using uniq will handle those
			main::uniq(\@temp) if @temp;
		}
	}
	@dms = @temp;
	my @dm_info;
	# print Data::Dumper::Dumper \@dms;
	# we know the files or directories exist so no need for further checks here
	foreach my $dm (@dms){
		@dm_info = ();
		($dm_info[0],$dm_info[1]) = ProgramData::full($dm,'',3);
		if (scalar @dms > 1 && (my $temp = ServiceData::get('status',$dm))){
			$dm_info[2] = main::message('stopped') if $temp && $temp =~ /stopped|disabled/;
		}
		push(@{$found->{$type}},[@dm_info]);
	}
	eval $end if $b_log;
}

sub test_ps_dm {
	eval $start if $b_log;
	PsData::set_dm();
	if (@{$ps_data{'dm-active'}}){
		my @dm_info;
		# ly does not have a run/pid file
		if (grep {$_ eq 'ly'} @{$ps_data{'dm-active'}}){
			($dm_info[0],$dm_info[1]) = ProgramData::full('ly','ly',3);
			$found->{'dm'}[0] = [@dm_info];
		}
		elsif (grep {/startx$/} @{$ps_data{'dm-active'}}){
			$found->{'dm'}[0] = ['startx'];
		}
		elsif (grep {$_ eq 'xinit'} @{$ps_data{'dm-active'}}){
			$found->{'dm'}[0] = ['xinit'];
		}
	}
	eval $end if $b_log;
}
}

## DistroData
{