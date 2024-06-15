package PackageData;
my ($count,$num,%pms,$type);
$pms{'total'} = 0;

sub get {
	eval $start if $b_log;
	# $num passed by reference to maintain incrementing where requested
	($type,$num) = @_;
	$loaded{'package-data'} = 1;
	my $output = {};
	package_counts();
	appimage_counts();
	create_output($output);
	eval $end if $b_log;
	return $output;
}

sub create_output {
	eval $start if $b_log;
	my $output = $_[0];
	my $total = '';
	if ($pms{'total'}){
		$total = $pms{'total'};
	}
	else {
		if ($type eq 'inner' || $pms{'disabled'}){
			$total = 'N/A' if $extra < 2;
		}
		else {
			$total = main::message('package-data');
		}
	}
	if ($pms{'total'} && $extra > 1){
		delete $pms{'total'};
		my $b_mismatch;
		foreach (keys %pms){
			next if $_ eq 'disabled';
			if ($pms{$_}->{'pkgs'} && $pms{$_}->{'pkgs'} != $total){
				$b_mismatch = 1;
				last;
			}
		}
		$total = '' if !$b_mismatch;
	}
	$output->{main::key($$num++,1,1,'Packages')} = $total;
	# if blocked pm secondary, only show if no total or improbable total
	if ($pms{'disabled'} && $extra < 2 && (!$pms{'total'} || $total < 100)){
		$output->{main::key($$num++,0,2,'note')} = $pms{'disabled'};
	}
	if ($extra > 1 && %pms){
		foreach my $pm (sort keys %pms){
			my ($cont,$ind) = (1,2);
			# if package mgr command returns error, this will not be a hash
			next if ref $pms{$pm} ne 'HASH';
			if ($pms{$pm}->{'pkgs'} || $b_admin || ($extra > 1 && $pms{$pm}->{'disabled'})){
				my $type = $pm;
				$type =~ s/^zzz-//; # get rid of the special sorters for items to show last
				$output->{main::key($$num++,$cont,$ind,'pm')} = $type;
				($cont,$ind) = (0,3);
				$pms{$pm}->{'pkgs'} = 'N/A' if $pms{$pm}->{'disabled'};
				$output->{main::key($$num++,($cont+1),$ind,'pkgs')} = $pms{$pm}->{'pkgs'};
				if ($pms{$pm}->{'disabled'}){
					$output->{main::key($$num++,$cont,$ind,'note')} = $pms{$pm}->{'disabled'};
				}
				if ($b_admin ){
					if ($pms{$pm}->{'libs'}){
						$output->{main::key($$num++,$cont,($ind+1),'libs')} = $pms{$pm}->{'libs'};
					}
					if ($pms{$pm}->{'tools'}){
						$output->{main::key($$num++,$cont,$ind,'tools')} = $pms{$pm}->{'tools'};
					}
				}
			}
		}
	}
	# print Data::Dumper::Dumper \%output;
	eval $end if $b_log;
}

sub package_counts {
	eval $start if $b_log;
	my ($type) = @_;
	# note: there is a program called discover which has nothing to do with kde
	# apt systems: plasma-discover, non apt, discover, but can't use due to conflict
	# my $disc = 'plasma-discover';
	my $gs = 'gnome-software';
	# 0: key; 1: program; 2: p/d [no-list]; 3: arg/path/no-list; 4: 0/1 use lib; 
	# 5: lib slice; 6: lib splitter; 7: optional eval test; 
	# 8: optional installed tool tests for -ra
	# needed: cards [nutyx], urpmq [mageia]
	my @pkg_managers = (
	['alps','alps','p','showinstalled',1,0,''],
	['apk','apk','p','info',1,0,''],
	# ['aptd','dpkg-query','d','/usr/lib/*',1,3,'\\/'],
	# mutyx. do cards test because there is a very slow pkginfo python pkg mgr
	['cards','pkginfo','p','-i',1,1,'','main::check_program(\'cards\')'], 
	# older dpkg-query do not support -f values consistently: eg ${binary:Package}
	['dpkg','dpkg-query','p','-W --showformat=\'${Package}\n\'',1,0,'','',
	 ['apt','apt-get','aptitude','deb-get','muon','nala','synaptic']],
	['emerge','emerge','d','/var/db/pkg/*/*/',1,5,'\\/'],
	['eopkg','eopkg','d','/var/lib/eopkg/package/*',1,5,'\\/'],
	['guix-sys','guix','p','package -p "/run/current-system/profile" -I',1,0,''],
	['guix-usr','guix','p','package -I',1,0,''],
	['kiss','kiss','p','list',1,0,''],
	['mport','mport','p','list',1,0,''],
	# netpkg puts packages in same place as slackpkg, only way to tell apart
	['netpkg','netpkg','d','/var/lib/pkgtools/packages/*',1,5,'\\/',
	'-d \'/var/netpkg\' && -d \'/var/lib/pkgtools/packages\'',
	 ['netpkg','sbopkg','sboui','slackpkg','slapt-get','slpkg','swaret']],
	['nix-sys','nix-store','p','-qR /run/current-system/sw',1,1,'-'], 
	['nix-usr','nix-store','p','-qR ~/.nix-profile',1,1,'-'], 
	['nix-default','nix-store','p','-qR /nix/var/nix/profiles/default',1,2,'-'], 
	['opkg','opkg','p','list',1,0,''], # ubuntu based Security Onion
	['pacman','pacman','p','-Qq --color never',1,0,'',
	 '!main::check_program(\'pacman-g2\')', # pacman-g2 has sym link to pacman
	 # these may need to be trimmed down depending on how useful/less some are
	 ['argon','aura','aurutils','baph','cylon','octopi','pacaur','pacseek',
	 'pakku','pamac','paru','pikaur','trizen','yaourt','yay','yup']], 
	['pacman-g2','pacman-g2','p','-Q',1,0,'','',],
	['pkg','pkg','d','/var/db/pkg/*',1,0,''], # 'pkg list' returns non programs
	['pkg_add','pkg_info','p','',1,0,''], # OpenBSD has set of tools, not 1 pm
	# like cards, avoid pkginfo directly due to python pm being so slow
	# but pkgadd is also found in scratch
	['pkgutils','pkginfo','p','-i',1,0,'','main::check_program(\'pkgadd\')'],
	# slack 15 moves packages to /var/lib/pkgtools/packages but links to /var/log/packages
	['pkgtool','installpkg','d','/var/lib/pkgtools/packages/*',1,5,'\\/',
	'!-d \'/var/netpkg\' && -d \'/var/lib/pkgtools/packages\'',
	 ['sbopkg','sboui','slackpkg','slapt-get','slpkg','swaret']],
	['pkgtool','installpkg','d','/var/log/packages/*',1,4,'\\/',
	'! -d \'/var/lib/pkgtools/packages\' && -d \'/var/log/packages/\'',
	 ['sbopkg','sboui','slackpkg','slapt-get','slpkg','swaret']],
	# rpm way too slow without nodigest/sig!! confirms packages exist
	# but even with, MASSIVELY slow in some cases, > 20, 30 seconds!!!!
	# find another way to get rpm package counts or don't show this feature for rpm!!
	['rpm','rpm','force','-qa --nodigest --nosignature',1,0,'',
	 'main::check_program(\'apt-get\') && main::check_program(\'dpkg\')',
	 ['dnf','packagekit','up2date','urpmi','yast','yum','zypper']],
	# uncommon case where apt-get frontend for rpm, w/o dpkg, like AltLinux did
	['rpm-apt','rpm','p','-qa',1,0,'',
	 'main::check_program(\'apt-get\') && !main::check_program(\'dpkg\')',
	 ['apt-get','rpm']],
	# scratch is a programming language too, with software called scratch
	['scratch','pkgbuild','d','/var/lib/scratchpkg/index/*/.pkginfo',1,5,'\\/',
	 '-d \'/var/lib/scratchpkg\''],
	# note: slackpkg, slapt-get, spkg, and pkgtool all return the same count
	# ['slackpkg','pkgtool','slapt-get','slpkg','swaret']],
	# ['slapt-get','slapt-get','p','--installed',1,0,''],
	# ['spkg','spkg','p','--installed',1,0,''],
	['tazpkg','tazpkg','p','list',1,0,'','',['tazpkgbox','tazpanel']],
	['tce','tce-status','p','-i',1,0,'','',['apps','tce-load']],
	# note: I believe mageia uses rpm internally but confirm
	# ['urpmi','urpmq','p','??',1,0,''], 
	['xbps','xbps-query','p','-l',1,1,''],
	# ['xxx-brew','brew','p','--cellar',0,0,''], # verify how this works
	['zzz-flatpak','flatpak','p','list',0,0,''],
	['zzz-snap','snap','p','list',0,0,'','@ps_cmd && (grep {/\bsnapd\b/} @ps_cmd)'],
	);
	my ($program);
	foreach my $pm (@pkg_managers){
		if ($program = main::check_program($pm->[1])){
			next if $pm->[7] && !eval $pm->[7];
			my ($disabled,$libs,@list,$pmts);
			if ($pm->[2] eq 'p' || ($pm->[2] eq 'force' && check_run($pm))){
				chomp(@list = qx($program $pm->[3] 2>/dev/null)) if $pm->[3];
			}
			elsif ($pm->[2] eq 'd'){
				@list = main::globber($pm->[3]);
			}
			else {
				# update message() if pm other than rpm disabled by default
				$disabled = main::message('pm-disabled',$pm->[1]);
			}
			$count = scalar @list if !$disabled;
			# print Data::Dumper::Dumper \@list;
			if (!$disabled){
				if ($b_admin && $count && $pm->[4]){
					$libs = count_libs(\@list,$pm->[5],$pm->[6]);
				}
			}
			else {
				$pms{'disabled'} = $disabled;
			}
			# if there is ambiguity about actual program installed, use this loop
			if ($b_admin && $pm->[8]){
				my @tools;
				foreach my $tool (@{$pm->[8]}){
					if (main::check_program($tool)){
						push(@tools,$tool);
					}
				}
				# only show gs if tools found, and if not added before
				if (@tools){
					if ($gs && main::check_program($gs)){
						push(@tools,$gs);
						$gs = '';
					}
				}
				if (@tools){
					main::make_list_value(\@tools,\$pmts,',','sort');
				}
			}
			$pms{$pm->[0]} = {
			'disabled' => $disabled,
			'pkgs' => $count,
			'libs' => $libs,
			'tools' => $pmts,
			};
			$pms{'total'} += $count if defined $count;
			# print Data::Dumper::Dumper \%pms;
		}
	}
	print 'package_counts %pms: ', Data::Dumper::Dumper \%pms if $dbg[65];
	main::log_data('dump','Package managers: %pms',\%pms) if $b_log;
	eval $end if $b_log;
}

sub appimage_counts {
	if (@ps_cmd && (grep {/\bappimage(d|launcher)\b/} @ps_cmd)){
		my @list = main::globber($ENV{'HOME'} . '/.{appimage/,local/bin/}*.[aA]pp[iI]mage');
		$count = scalar @list;
		$pms{'zzz-appimage'} = {
		'pkgs' => $count,
		'libs' => undef,
		};
		$pms{'total'} += $count;
	}
}

sub check_run {
	if ($force{'pkg'}){
		return 1;
	}
	elsif (${_[0]}->[1] eq 'rpm'){
		# testing for core wrappers for rpm, these should not be present in non
		# redhat/suse based systems. mageia has urpmi, dnf, yum
		foreach my $tool (('dnf','up2date','urpmi','yum','zypper')){
			return 0 if main::check_program($tool);
		}
		# Note: test fails: apt-rpm (pclinuxos,alt linux), unknown how to detect
		# Add pm test if known to have rpm available.
		foreach my $tool (('dpkg','pacman','pkgtool','tce-load')){
			return 1 if main::check_program($tool);
		}
	}
}

sub count_libs {
	my ($items,$pos,$split) = @_;
	my (@data);
	my $i = 0;
	$split ||= '\\s+';
	# print scalar @$items, '::', $split, '::', $pos, "\n";
	foreach (@$items){
		@data = split(/$split/, $_);
		# print scalar @data, '::', $data[$pos], "\n";
		$i++ if $data[$pos] && $data[$pos] =~ m%^lib%;
	}
	return $i;
}
}

## ParseEDID
{