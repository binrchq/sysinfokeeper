package DesktopData;
my ($b_dbg_de,$desktop_session,$gdmsession,$kde_full_session,
$kde_session_version,$tk_test,$xdg_desktop,@data,%xprop);
my $desktop = [];

sub get {
	eval $start if $b_log;
	$b_dbg_de = 1 if $dbg[63] || $b_log;
	PsData::set_de_wm() if !$loaded{'ps-gui'};
	set_env_data();
	# the order of these tests matters, go from most to least common
	de_kde_tde_data();
	de_env_data() if !@$desktop;
	if (!@$desktop){
		# NOTE: Always add to set_prop the search term if you add an item!!
		set_xprop() if !$loaded{'xprop'};
		de_gnome_based_data();
	}
	de_xfce_data() if !@$desktop;
	de_enlightenment_based_data() if !@$desktop;
	de_misc_data() if !@$desktop;
	# last try, get it from ps data
	de_ps_data() if !@$desktop;
	if ($extra > 2 && @$desktop){
		components_data(); # bars, docks, menu, panels, trays etc
		tools_data(); # screensavers, lockers
	}
	if ($b_display && !$force{'display'} && $extra > 1){
		wm_data();
	}
	# we want tk, but no previous methods got it
	if ($extra > 1 && !$desktop->[3] && $tk_test){
		if ($tk_test eq 'gtk'){
			tk_gtk_data();}
		elsif ($tk_test eq 'qt'){
			tk_qt_data();}
		else {
			tk_misc_data();}
	}
	# try to avoid repeat version calls for wm/compostors
	if ($show{'graphic'} && @$desktop){
		$comps{lc($desktop->[0])} = [$desktop->[0],$desktop->[1]] if $desktop->[0];
		$comps{lc($desktop->[5])} = [$desktop->[5],$desktop->[6]] if $desktop->[5];
	}
	if ($b_log){
		main::log_data('dump','@$desktop', $desktop);
		main::log_data('dump','%comps', \%comps);
	}
	if ($dbg[59]){
		print '$desktop: ', Data::Dumper::Dumper $desktop;
		print '%comps: ', Data::Dumper::Dumper \%comps;
	}
	eval $end if $b_log;
	return $desktop;
}

## DE SPECIFIC IDS ##

# ENLIGHTENMENT/MOKSHA #
sub de_enlightenment_based_data {
	eval $start if $b_log;
	# print 'de evn xprop: ', Data::Dumper::Dumper \%xprop;
	my ($v_src,$program);
	# earlier moksha fully ID as enlightenment
	if ($xdg_desktop eq 'moksha' || $gdmsession eq 'moksha' || 
	($xprop{'moksha'} && 
	(main::check_program('enlightenment') || main::check_program('moksha')))){
		# ENLIGHTENMENT_VERSION(STRING) = "Moksha 0.2.0.15989"
		# note: toolkit: EFL
		# later releases have -version
		if ($v_src = main::check_program('moksha')){
			($desktop->[0],$desktop->[1]) = ProgramData::full('moksha',$v_src);
		}
		# Earlier: no -v or --version but version is in xprop -root
		if (!$desktop->[1] && $xprop{'moksha'}){
			$v_src = 'xprop';
			$desktop->[1] = main::awk($xprop{'moksha'}->{'lines'},
			'(enlightenment|moksha)_version',2,'\s+=\s+');
			$desktop->[1] =~ s/"?(moksha|enlightenment)\s([^"]+)"?/$2/ if $desktop->[1];
		}
		$desktop->[0] ||= 'Moksha';
	}
	elsif ($xdg_desktop eq 'enlightenment' || $gdmsession eq 'enlightenment' || 
	($xprop{'enlightenment'} && main::check_program('enlightenment'))){
		# no -v or --version but version is in xprop -root
		# ENLIGHTENMENT_VERSION(STRING) = "Enlightenment 0.16.999.49898"
		$desktop->[0] = 'Enlightenment';
		if ($xprop{'enlightenment'}){
			$v_src = 'xprop';
			$desktop->[1] = main::awk($xprop{'enlightenment'}->{'lines'},
			'(enlightenment|moksha)_version',2,'\s+=\s+');
			$desktop->[1] =~ s/"?(moksha|enlightenment)\s([^"]+)"?/$2/ if $desktop->[1];
		}
	}
	if ($desktop->[0]){
		if ($extra > 1 && ($program = main::check_program('efl-version'))){
			($desktop->[2],$desktop->[3]) = ProgramData::full('efl-version',$program);
		}
		$desktop->[2] ||= 'EFL' if $extra > 1;
		main::feature_debugger('de ' . $desktop->[0] . ' v_src,program,desktop',
		[$v_src,$program,$desktop],$dbg[63]) if $b_dbg_de;
	}
	eval $end if $b_log;
}

# GNOME/CINNAMON/MATE #
sub de_gnome_based_data {
	eval $start if $b_log;
	# add more as discovered
	return if $xdg_desktop eq 'xfce' || $gdmsession eq 'xfce';
	my ($program,$value,@version_data);
	# note that cinnamon split from gnome, and and can now be id'ed via xprop,
	# but it will still trigger the next gnome true case, so this needs to go 
	# before gnome test eventually this needs to be better organized so all the 
	# xprop tests are in the same section, but this is good enough for now.
	# NOTE: was checking for 'muffin' but that's not part of cinnamon
	if ($xdg_desktop eq 'cinnamon' || $gdmsession eq 'cinnamon' || 
	(($xprop{'muffin'} || $xprop{'mutter'}) && 
	(main::check_program('muffin') || main::check_program('cinnamon-session')))){
		($desktop->[0],$desktop->[1]) = ProgramData::full('cinnamon','cinnamon',0);
		$tk_test = 'gtk';
		$desktop->[0] ||= 'Cinnamon';
		main::feature_debugger('gnome test 1 $desktop',$desktop,$dbg[63]) if $b_dbg_de;
	}
	elsif ($xdg_desktop eq 'mate' || $gdmsession eq 'mate' || $xprop{'marco'}){
		# NOTE: mate-about and mate-sesssion vary which has the higher number, neither 
		# consistently corresponds to the actual MATE version, so check both.
		my %versions = ('mate-about' => '','mate-session' => '');
		foreach my $key (keys %versions){
			if ($program = main::check_program($key)){
				($desktop->[0],$versions{$key}) = ProgramData::full($key,$program,0);
			}
		}
		# no consistent rule about which version is higher, so just compare them and take highest
		$desktop->[1] = main::compare_versions($versions{'mate-about'},$versions{'mate-session'});
		# $tk_test = 'gtk';
		$desktop->[0] ||= 'MATE';
		main::feature_debugger('gnome test 2 $desktop',$desktop,$dbg[63]) if $b_dbg_de;
	}
	# See sub for logic and comments
	elsif (check_gnome()){
		if (main::check_program('gnome-about')){
			($desktop->[0],$desktop->[1]) = ProgramData::full('gnome-about');
		}
		elsif (main::check_program('gnome-shell')){
			($desktop->[0],$desktop->[1]) = ProgramData::full('gnome','gnome-shell');
		}
		$tk_test = 'gtk';
		$desktop->[0] ||= 'GNOME';
		main::feature_debugger('gnome test 3 $desktop $desktop',$desktop,
		$dbg[63]) if $b_dbg_de;
	}
	eval $end if $b_log;
}

# Note, GNOME_DESKTOP_SESSION_ID is deprecated so we'll see how that works out
# https://bugzilla.gnome.org/show_bug.cgi?id=542880.
# NOTE: manjaro is leaving XDG data null, which forces the manual check for gnome, sigh...
# some gnome programs can trigger a false xprop gnome ID
# _GNOME_BACKGROUND_REPRESENTATIVE_COLORS(STRING) = "rgb(23,31,35)"
sub check_gnome {
	eval $start if $b_log;
	my ($b_gnome,$detection) = (0,'');
	if ($xdg_desktop && $xdg_desktop =~ /gnome/){
		$detection = 'xdg_current_desktop';
		$b_gnome = 1;
	}
	# should work as long as string contains gnome, eg: peppermint:gnome 
	# filtered explicitly in set_env_data
	elsif ($xdg_desktop && $xdg_desktop !~ /gnome/){
		$detection = 'xdg_current_desktop';
	}
	# possible values: lightdm-xsession, only positive match tests will work
	elsif ($gdmsession && $gdmsession eq 'gnome'){
		$detection = 'gdmsession';
		$b_gnome = 1;
	}
	# risky: Debian: $DESKTOP_SESSION = lightdm-xsession; Manjaro/Arch = xfce
	# note that mate/cinnamon would already have been caught so no need to add 
	# explicit tests for them
	elsif ($desktop_session && $desktop_session eq 'gnome'){
		$detection = 'desktop_session';
		$b_gnome = 1;
	}
	# possible value: this-is-deprecated, but I believe only gnome based desktops
	# set this variable, so it doesn't matter what it contains
	elsif ($ENV{'GNOME_DESKTOP_SESSION_ID'}){
		$detection = 'gnome_destkop_session_id';
		$b_gnome = 1;
	}
	# maybe use ^_gnome_session instead? try it for a while
	elsif ($xprop{'gnome_session'} && main::check_program('gnome-shell')){
		$detection = 'xprop-root';
		$b_gnome = 1;
	}
	if ($b_dbg_de && $b_gnome){
		main::feature_debugger('gnome $detection','detect-type: ' . $detection,$dbg[63]);
	}
	main::log_data('data','$detection:$b_gnome>>' . $detection . ":$b_gnome") if $b_log;
	eval $end if $b_log;
	return $b_gnome;
}

# KDE/TRINITY #
sub de_kde_tde_data {
	eval $start if $b_log;
	my ($kded,$kded_name,$program,$tk_src,$v_data,$v_src);
	# we can't rely on 3 using kded3, it could be kded
	if ($kde_session_version && ($program = main::check_program('kded' . $kde_session_version))){
		$kded = $program;
		$kded_name = 'kded' . $kde_session_version;
	}
	elsif ($program = main::check_program('kded')){
		$kded = $program;
		$kded_name = 'kded';
	}
	# note: if TDM is used to start kde, can pass ps tde test
	if ($desktop_session eq 'trinity' || $xdg_desktop eq 'trinity' || 
	(!$desktop_session && !$xdg_desktop && @{$ps_data{'de-ps-detect'}} && 
	(grep {/^tde/} @{$ps_data{'de-ps-detect'}}))){
		if ($program = main::check_program('kdesktop')){
			($desktop->[0],$desktop->[1],$v_data) = ProgramData::full('kdesktop-trinity',$program,0,'raw');
		}
		if ($extra > 1 && $v_data && @$v_data){
			($desktop->[2],$desktop->[3]) = item_from_version($v_data,['^Qt:',2,'Qt']);
		}
		$desktop->[0] ||= 'Trinity';
		$desktop->[2] ||= 'Qt' if $extra > 1;
		main::feature_debugger('kde trinity $program,$v_data,$desktop',
		[$program,$v_data,$desktop],$dbg[63]) if $b_dbg_de;
	}
	# works on 4, assume 5 will id the same, why not, no need to update in future
	# KDE_SESSION_VERSION is the integer version of the desktop
	# NOTE: as of plasma 5, the tool: about-distro MAY be available, that will show
	# actual desktop data, so once that's in debian/ubuntu, if it gets in, add that test
	elsif ($desktop_session eq 'kde-plasma' || $desktop_session eq 'plasma' || 
	$xdg_desktop eq 'kde' || $kde_session_version){
		# KDE <= 4
		if ($kde_session_version && $kde_session_version <= 4){
			if ($program = main::check_program($kded_name)){
				($desktop->[0],$desktop->[1],$v_data) = ProgramData::full($kded_name,$program,0,'raw');
				if ($extra > 1 && $v_data && @$v_data){
					($desktop->[2],$desktop->[3]) = item_from_version($v_data,['^Qt:',2,'Qt']);
				}
			}
			$desktop->[0] ||= 'KDE';
			$desktop->[2] ||= 'Qt' if $extra > 1;
			main::feature_debugger('kde 4 program,v_data,$desktop',
			[$program,$v_data,$desktop],$dbg[63]) if $b_dbg_de;
		}
		# KDE >= 5
		else {
			# no qt data, just the kde version as of 5, not in kde4
			my $fw_src;
			if (!$desktop->[0] && 
			($v_src = $program = main::check_program("plasmashell"))){
				($desktop->[0],$desktop->[1]) = ProgramData::full('plasmashell',$program);
			}
			# kwin through version 4 showed full kde/qt data, 5 only shows plasma version
			if (!$desktop->[0] && 
			($v_src = $program = main::check_program("kwin"))){
				($desktop->[0],$desktop->[1]) = ProgramData::full('kwin-kde',$program);
			}
			$desktop->[0] = 'KDE Plasma';
			if (!$desktop->[1]){
				$desktop->[1] = ($kde_session_version) ? 
					$kde_session_version : main::message('unknown-desktop-version');
			}
			# NOTE: this command string is almost certain to change, and break, with next 
			# major plasma desktop, ie, 6. 
			# qdbus org.kde.plasmashell /MainApplication org.qtproject.Qt.QCoreApplication.applicationVersion
			# kde 4: kwin,kded4 (KDE:); kde5: kf5-config (KDE Frameworks:)
			# Qt: 5.4.2
			# KDE Frameworks: 5.11.0
			# kf5-config: 1.0
			# for QT, and Frameworks if we use it. Frameworks v is NOT same as KDE v.
			if ($extra > 1){
				if ($tk_src = $program = main::check_program("kf$kde_session_version-config")){
					($desktop->[2],$desktop->[3],$v_data) = ProgramData::full(
					 "kf-config-qt",$program,0,'raw');
				}
				if (!$desktop->[3] && (!$v_data || !@$v_data) &&  
				($tk_src = $program = main::check_program("kf-config"))){
					($desktop->[2],$desktop->[3],$v_data) = ProgramData::full(
					 "kf-config-qt",$program,0,'raw');
				}
				$desktop->[2] ||= 'Qt';
				if ($b_admin){
					if ($v_data && @$v_data){
						$fw_src = $tk_src;
						($desktop->[9],$desktop->[10]) = item_from_version($v_data,
						['^KDE Frameworks:',3,'frameworks']);
					}
					# This has Frameworks version as of kde 5
					if ($kded && !$desktop->[10]){
						$fw_src = $kded;
						($desktop->[9],$desktop->[10]) = ProgramData::full($kded_name . '-frameworks',$kded);
					}
				}
			}
			main::feature_debugger('kde >= 5 v_src,tk_src,fw_src,v_data,$desktop',
			[$v_src,$tk_src,$fw_src,$v_data,$desktop],$dbg[63]) if $b_dbg_de;
		}
	}
	# KDE_FULL_SESSION property is only available since KDE 3.5.5. This will only
	# trigger for KDE 3.5, since above conditions catch >= 4
	elsif ($kde_full_session eq 'true'){
		# this is going to be bad data since new kdedX is different version from kde
		($desktop->[0],$desktop->[1],$v_data) = ProgramData::full($kded_name,$kded,0,'raw');
		$desktop->[1] ||= '3.5';
		if ($extra > 1 && $v_data && @$v_data){
			($desktop->[2],$desktop->[3]) = item_from_version($v_data,['^Qt:',2,'Qt']);
			
		}
		$desktop->[2] ||= 'Qt' if $extra > 1;
		main::feature_debugger('kde 3.5 de+qt $desktop',$desktop,$dbg[63]) if $b_dbg_de;
	}
	eval $end if $b_log;
}

# XFCE #
# Not strictly dependent on xprop data, which is not necessarily always present
sub de_xfce_data {
	eval $start if $b_log;
	my ($program,$v_data);
	# print 'de-xfce-env: ', Data::Dumper::Dumper \%xprop;
	# String: "This is xfdesktop version 4.2.12"
	# alternate: xfce4-about --version > xfce4-about 4.10.0 (Xfce 4.10)
	# note: some distros/wm (e.g. bunsen) set $xdg_desktop to xfce to solve some
	# other issues so but are OpenBox. Not inxi issue. 
	# $xdg_desktop can be /usr/bin/startxfce4
	# print "xdg_d: $xdg_desktop gdms: $gdmsession\n";
	if ($xdg_desktop eq 'xfce' || $gdmsession eq 'xfce' || 
	(($xprop{'xfdesktop'} || $xprop{'xfce'}) && main::check_program('xfdesktop'))){
		($desktop->[0],$desktop->[1],$v_data) = ProgramData::full('xfdesktop','',0,'raw');
		if (!$desktop->[1]){
			my $version = '4'; # just assume it's 4, we tried
			if ($program = main::check_program('xfce4-panel')){
				$version = '4';
			}
			# talk to xfce to see what id they will be using for xfce 5
			elsif ($program = main::check_program('xfce5-panel')){
				$version = '5';
			}
			# they might get rid of number, we'll see
			elsif ($program = main::check_program('xfce-panel')){
				$version = '';
			}
			# xfce4-panel does not show built with gtk [version]
			# this returns an error message to stdout in x, which breaks the version
			# xfce4-panel --version out of x fails to get display, so no data
			# out of x this kicks out an error: xfce4-panel: Cannot open display
			($desktop->[0],$desktop->[1]) = ProgramData::full("xfce${version}-panel",$program);
		}
		$desktop->[0] ||= 'Xfce';
		$desktop->[1] ||= ''; # xfce isn't going to be 4 forever
		if ($extra > 1 && $v_data && @$v_data){
			($desktop->[2],$desktop->[3]) = item_from_version($v_data,['^Built with GTK',4,'Gtk']);
		}
		main::feature_debugger('xfce $program,$desktop',[$program,$desktop],
		$dbg[63]) if $b_dbg_de;
	}
	eval $end if $b_log;
}

## GENERAL DE TESTS ##
sub de_env_data {
	eval $start if $b_log;
	if (!$desktop->[0]){
		my $v_data;
		# 0: 0/1 regex/eq; 1: env var search; 2: PD full; 3: [PD version cmd]; 
		# 4: tk; 5: ps search; 
		# 6: [toolkits data sourced from full version [search,position,print]]
		my @desktops =(
		[1,'unity','unity','',''],
		[0,'budgie','budgie-desktop','','gtk'],
		# debian package: lxde-core. 
		# NOTE: some distros fail to set XDG data for root, ps may get it
		[1,'lxde','lxpanel','','gtk-na',',^lxsession$'], # no gtk v data, not same as system
		[1,'razor','razor-session','','qt','^razor-session$'],
		# BAD: lxqt-about opens dialogue, sigh. 
		# Checked, lxqt-panel does show same version as lxqt-about/session
		[1,'lxqt','lxqt-panel','','qt','^lxqt-session$',['Qt',2,'Qt']],
		[0,'^(razor|lxqt)$','lxqt-variant','','qt','^(razor-session|lxqt-session)$'],
		[1,'fvwm-crystal','fvwm-crystal','fvwm',''],
		[1,'hyprland','hyprctl','',''],
		[1,'blackbox','blackbox','',''],
		# note, X-Cinnamon value strikes me as highly likely to change, so just 
		# search for the last part
		[1,'nscde','nscde','',''],# has to go before cde
		[0,'cde','cde','','motif'],
		[0,'cinnamon','cinnamon','','gtk'],
		# these so far have no cli version data
		[1,'deepin','deepin','','qt'], # version comes from file read
		[1,'draco','draco','','qt'],
		[1,'leftwm','leftwm','',''],
		[1,'mlvwm','mlvwm','',''],
		[0,'^(motif\s?window|mwm)','mwm','','motif'],
		[1,'pantheon','pantheon','','gtk'],
		[1,'penrose','penrose','',''],# unknown, just guessing 
		[1,'lumina','lumina-desktop','','qt'],
		[0,'manokwari','manokwari','','gtk'],
		[1,'ukui','ukui-session','','qt'],
		[0,'wmaker|windowmaker','windowmaker','wmaker',''],
		);
		foreach my $item (@desktops){
			# Check if in xdg_desktop OR desktop_session OR if in $item->[5] and in ps_gui
			if ((($item->[0] && 
			($xdg_desktop eq $item->[1] || $desktop_session eq $item->[1])) ||
			(!$item->[0] && 
			($xdg_desktop =~ /$item->[1]/ || $desktop_session  =~ /$item->[1]/))) ||
			($item->[5] && 
			@{$ps_data{'de-ps-detect'}} && (grep {/$item->[5]/} @{$ps_data{'de-ps-detect'}}))){
				($desktop->[0],$desktop->[1],$v_data) = ProgramData::full($item->[2],$item->[3],0,$item->[6]);
				if ($extra > 1){
					if ($item->[6] && $v_data && @$v_data){
						($desktop->[2],$desktop->[3]) = item_from_version($v_data,$item->[6]);
					}
					$tk_test = $item->[4] if !$desktop->[3];
				}
				main::feature_debugger('env de-wm',$desktop,$dbg[63]) if $b_dbg_de;
				last;
			}
		}
	}
	eval $end if $b_log;
}

# These require data from xprop.
sub de_misc_data {
	eval $start if $b_log;
	# print 'de evn xprop: ', Data::Dumper::Dumper \%xprop;
	# the sequence here matters, some desktops like icewm, razor, let you set different 
	# wm, so we want to get the main controlling desktop first, then fall back to the wm
	# detections. de_ps_data() and wm_data() will handle alternate wm detections.
	if (%xprop){
		# order matters! These are the primary xprop detected de/wm
		my $program;
		my @desktops = qw(icewm i3 mwm windowmaker wm2 herbstluftwm fluxbox blackbox 
		openbox amiwm);
		foreach my $de (@desktops){
			if ($xprop{$de} && 
			(($program = main::check_program($xprop{$de}->{'name'})) || 
			($xprop{$de}->{'vname'} && ($program = main::check_program($xprop{$de}->{'vname'}))))){
				($desktop->[0],$desktop->[1]) = ProgramData::full($xprop{$de}->{'name'},$program);
				main::feature_debugger('de misc $program,$desktop',
				[$program,$desktop],$dbg[63]) if $b_dbg_de;
				last;
			}
		}
	}
	# need to check starts line because it's so short
	eval $end if $b_log;
}

sub de_ps_data {
	eval $start if $b_log;
	my ($v_data,@working);
	# The sequence here matters, some desktops like icewm, razor, let you set different
	# wm, so we want to get the main controlling desktop first
	# icewm and any other that permits alternate wm to be used need to go first
	push(@working,@{$ps_data{'wm-parent'}}) if @{$ps_data{'wm-parent'}};
	push(@working,@{$ps_data{'wm-compositors'}}) if @{$ps_data{'wm-compositors'}};
	push(@working,@{$ps_data{'wm-main'}}) if @{$ps_data{'wm-main'}};
	if (@working){
		# order matters, these have alternate search patterns from default name
		# 0: check program; 1: ps_gui search; 2: PD full; 3: [PD version cmd]
		my @wms =(
		['WindowMaker','(WindowMaker|wmaker)','wmaker',''],
		['cwm','(openbsd-)?cwm','cwm',''],
		['flwm','flwm(_topside)?','flwm',''],
		['fvwm-crystal','fvwm.*-crystal\S*','fvwm-crystal','fvwm'],
		['hyprland','[Hh]yprland','hyprctl',''],
		['xfdesktop','xfdesktop','xfdesktop','',['^Built with GTK',4,'Gtk']],
		);
		# note: use my $item to avoid bizarre return from program_data to ps_gui write
		foreach my $item (@wms){
			# no need to use check program with short list of ps_gui
			# print "1: $item->[1]\n";
			if (grep {/^$item->[1]$/i} @working){
				# print "2: $item->[1]\n";
				($desktop->[0],$desktop->[1],$v_data) =  ProgramData::full($item->[2],$item->[3],0,$item->[4]);
				if ($extra > 1 && $item->[4] && $v_data && @$v_data){
					($desktop->[2],$desktop->[3]) = item_from_version($v_data,$item->[4]);
				}
				main::feature_debugger('ps de test 1 $desktop',
				$desktop,$dbg[63]) if $b_dbg_de;
				last;
			}
		}
		if (!$desktop->[0]){
			# we're relying on the stack order to get primary before secondary wm
			my $de = shift(@working);
			($desktop->[0],$desktop->[1]) = ProgramData::full($de);
			main::feature_debugger('ps de test 2 $desktop',
			$desktop,$dbg[63]) if $b_dbg_de;
		}
	}
	eval $end if $b_log;
}

## TOOLKIT DATA ##
# NOTE: used to use a super slow method here, but gtk-launch returns
# the gtk version I believe
sub tk_gtk_data {
	eval $start if $b_log;
	if (main::check_program('gtk-launch')){
		($desktop->[2],$desktop->[3]) = ProgramData::full('gtk-launch');
		main::feature_debugger('gtk $desktop 2,3',
		[$desktop->[2],$desktop->[3]],$dbg[63]) if $b_dbg_de;
	}
	eval $end if $b_log;
}

# This handles stray tooltips that won't get versions, yet anyway.
sub tk_misc_data {
	eval $start if $b_log;
	if ($tk_test eq 'gtk-na'){
		$desktop->[2] = 'Gtk';
	}
	else {
		$desktop->[2] = ucfirst($tk_test);
	}
	eval $end if $b_log;
}

# Note ideally most of these are handled by item_from_version, but these will 
# handle as fallback detections as those are updated, if possible. 
sub tk_qt_data {
	eval $start if $b_log;
	my $program;
	my $kde_version = $kde_session_version;
	if (!$kde_version){
		if ($program = main::check_program("kded6")){
			$kde_version = 6;}
		elsif ($program = main::check_program("kded5")){
			$kde_version = 5;}
		elsif ($program = main::check_program("kded4")){
			$kde_version = 4;}
		elsif ($program = main::check_program("kded")){
			$kde_version = '';}
	}
	# alternate: qt4-default, qt4-qmake or qt5-default, qt5-qmake
	# often this exists, is executable, but actually is nothing, shows error
	if (!$desktop->[3] && ($program = main::check_program('qmake'))){
		($desktop->[2],$desktop->[3]) = ProgramData::full('qmake-qt',$program);
	}
	if (!$desktop->[3] && ($program = main::check_program('qtdiag'))){
		($desktop->[2],$desktop->[3]) = ProgramData::full('qtdiag-qt',$program);
	}
	if (!$desktop->[3] && ($program = main::check_program("kf$kde_version-config"))){
		($desktop->[2],$desktop->[3]) = ProgramData::full('kf-config-qt',$program);
	}
	# note: qt 5 does not show qt version in kded5, sigh
	if (!$desktop->[3] && ($program = main::check_program("kded$kde_version"))){
		($desktop->[2],$desktop->[3]) = ProgramData::full('kded-qt',$program);
	}
	if ($b_dbg_de && ($desktop->[2] || $desktop->[3])){
		main::feature_debugger('qt $program,qt,v $desktop 2,3',
		[$program,$desktop->[2],$desktop->[3]],$dbg[63]);
	}
	eval $end if $b_log;
}

## WM DATA ## 
sub wm_data {
	eval $start if $b_log;
	my $b_wm;
	if (!$force{'wmctrl'}){
		set_xprop() if !$loaded{'xprop'};
		wm_ps_xprop_data(\$b_wm);
	}
	# note, some wm, like cinnamon muffin, do not appear in ps aux, but do in wmctrl
	if (((!$b_wm && !$desktop->[5]) || $force{'wmctrl'}) && 
	(my $program = main::check_program('wmctrl'))){
		wm_wmctrl_data($program);
	}
	eval $end if $b_log;
}

# args: 0: $b_wm ref
sub wm_ps_xprop_data {
	eval $start if $b_log;
	my $b_wm = $_[0];
	my @wms;
	# order matters, see above logic
	push(@wms,@{$ps_data{'de-wm-compositors'}}) if @{$ps_data{'de-wm-compositors'}};
	push(@wms,@{$ps_data{'wm-compositors'}}) if @{$ps_data{'wm-compositors'}};
	push(@wms,@{$ps_data{'wm-main'}}) if @{$ps_data{'wm-main'}};
	# eg: blackbox parent of icewm, icewm parent of blackbox
	push(@wms,@{$ps_data{'wm-parent'}}) if @{$ps_data{'wm-parent'}};
	# leave off parent since that would always be primary
	foreach my $wm (@wms){
		if ($wm eq 'windowmaker'){
			$wm = 'wmaker';}
		wm_version('manual',$wm,$b_wm);
		if ($desktop->[5]){
			main::feature_debugger('ps wm,v $desktop 5,6',
			[$desktop->[5],$desktop->[6]],$dbg[63]) if $b_dbg_de;
			last;
		}
	}
	# xprop is set only if not kde/gnome/cinnamon/mate/budgie/lx. Issues with 
	# fluxbox blackbox_pid false detection, so run this as fallback.
	if (!$desktop->[5] && %xprop){
		# print "wm ps xprop: ", Data::Dumper::Dumper \%xprop;
		# KWIN_RUNNING, note: the actual xprop filters handle position and _ type syntax
		# don't use i3, it's not unique enough in this test, can trigger false positive
		@wms = qw(amiwm blackbox bspwm compiz kwin_x11 kwinft kwin 
		marco motif muffin mutter openbox herbstluftwm twin ukwm wm2 windowmaker);
		my $working;
		foreach my $wm (@wms){
			last if $desktop->[0] && $wm eq lc($desktop->[0]); # catch odd stuff like wmaker
			if ($xprop{$wm}){
				$working = $wm;
				if ($working eq 'mutter' && $desktop->[0] && lc($desktop->[0]) eq 'cinnamon'){
					$working = 'muffin';
				}
				$working = $xprop{$wm}->{'vname'} if $xprop{$wm}->{'vname'};
				wm_version('manual',$working,$b_wm);
				main::feature_debugger('xprop wm,v $desktop 5,6',
				[$desktop->[5],$desktop->[6]],$dbg[63]) if $b_dbg_de;
				last;
			}
		}
	}
	eval $end if $b_log;
}

sub wm_wmctrl_data {
	eval $start if $b_log;
	my ($program) = @_;
	my $cmd = "$program -m 2>/dev/null";
	my @data = main::grabber($cmd,'','strip');
	main::log_data('dump','@data',\@data) if $b_log;
	$desktop->[5] = main::awk(\@data,'^Name',2,'\s*:\s*');
	# qtile,scrotwm,spectrwm have an odd fake wmctrl wm for irrelevant reasons
	# inxi doesn't support lg3d, if support added update this, but assume bad
	if ($desktop->[5] && ($desktop->[5] eq 'N/A' || 
	($desktop->[0] && $desktop->[5] eq 'LG3D'))){
		$desktop->[5] = '';
	}
	if ($desktop->[5]){
		# variants: gnome shell; 
		# IceWM 1.3.8 (Linux 3.2.0-4-amd64/i686) ; Metacity (Marco) ; Xfwm4
		$desktop->[5] =~ s/\d+\.\d\S+|[\[\(].*\d+\.\d.*[\)\]]//g;
		$desktop->[5] = main::trimmer($desktop->[5]);
		# change Metacity (Marco) to marco
		if ($desktop->[5] =~ /marco/i){
			$desktop->[5] = 'marco';}
		elsif ($desktop->[5] =~ /muffin/i){
			$desktop->[5] = 'muffin';}
		elsif (lc($desktop->[5]) eq 'gnome shell'){
			$desktop->[5] = 'gnome-shell';}
		elsif ($desktop_session eq 'trinity' && lc($desktop->[5]) eq 'kwin'){
			$desktop->[5] = 'Twin';}
		wm_version('wmctrl',$desktop->[5]);
		main::feature_debugger('wmctrl wm,v $desktop 5,6',
		[$desktop->[5],$desktop->[6]],$dbg[63]) if $b_dbg_de;
	}
	eval $end if $b_log;
}

# args: 0: manual/wmctrl; 1: wm; 2: $b_wm ref
sub wm_version {
	eval $start if $b_log;
	my ($type,$wm,$b_wm) = @_;
	# we don't want the gnome-shell version, and the others have no --version
	# we also don't want to run --version again on stuff we already have tested
	if (!$wm || ($desktop->[0] && lc($desktop->[0]) eq lc($wm))){
		# we don't want to run wmctrl if we got a matching de/wm set
		$$b_wm = 1 if $wm; 
		return;
	}
	elsif ($wm && $wm =~ /^(budgie-wm|gnome-shell)$/){
		$desktop->[5] = $wm;
		return;
	}
	my $temp = (split(/\s+/, $wm))[0];
	if ($temp){
		$temp = (split(/\s+/, $temp))[0];
		$temp = lc($temp);
		$temp = 'wmaker' if $temp eq 'windowmaker';
		my @data = ProgramData::full($temp,$temp,3);
		return if !$data[0];
		# print Data::Dumper::Dumper \@data;
		$desktop->[5] = $data[0] if $type eq 'manual';
		$desktop->[6] = $data[1] if $data[1];
	}
	eval $end if $b_log;
}

## PARTS/TOOLS DATA ##
sub components_data {
	eval $start if $b_log;
	if (@{$ps_data{'components-active'}}){
		main::make_list_value($ps_data{'components-active'},\$desktop->[4],',','sort');
	}
	eval $end if $b_log;
}

sub tools_data {
	eval $start if $b_log;
	# these are running/active
	if (@{$ps_data{'tools-active'}}){
		main::make_list_value($ps_data{'tools-active'},\$desktop->[7],',','sort');
	}
	# now check if any are available but not running/services
	if ($b_admin){
		my %test;
		my $installed = [];
		if ($desktop->[7]){
			foreach my $tool (@{$ps_data{'tools-active'}}){
				$test{$tool} = 1;
			}
		}
		foreach my $item (@{$ps_data{'tools-test'}}){
			next if $test{$item};
			if (main::check_program($item)){
				push(@$installed,$item);
			}
		}
		if (@$installed){
			main::make_list_value($installed,\$desktop->[8],',','sort');
		}
	}
	eval $end if $b_log;
}

## UTILITIES ##

# args: 0: raw $version data ref; 1: [search regex, split pos, print name]
#  returns item print name, version
sub item_from_version {
	eval $start if $b_log;
	my ($item,$version);
	if (!$_[0] || !$_[1] || ref $_[0] ne 'ARRAY'){
		eval $end if $b_log;
		return;
	}
	foreach my $line (@{$_[0]}){
		# print "line: $line\n";
		if ($line =~ /${$_[1]}[0]/){
			my @data = split(/\s+/,$line);
			# print 'ifv main: ', Data::Dumper::Dumper \@data;
			($item,$version) = (${$_[1]}[2],$data[${$_[1]}[1] - 1]);
			last;
		}
	}
	$version =~ s/[,_\.-]$//g if $version; # trim off gunk
	eval $end if $b_log;
	return ($item,$version);
}

# note: for tests, all values are lowercased.
sub set_env_data {
	# NOTE $XDG_CURRENT_DESKTOP envvar is not reliable, but it shows certain desktops better.
	# most desktops are not using it as of 2014-01-13 (KDE, UNITY, LXDE. Not Gnome)
	$desktop_session = ($ENV{'DESKTOP_SESSION'}) ? clean_env($ENV{'DESKTOP_SESSION'}) : '';
	$xdg_desktop = ($ENV{'XDG_CURRENT_DESKTOP'}) ? clean_env($ENV{'XDG_CURRENT_DESKTOP'}) : '';
	$kde_full_session = ($ENV{'KDE_FULL_SESSION'}) ? clean_env($ENV{'KDE_FULL_SESSION'}) : '';
	$kde_session_version = ($ENV{'KDE_SESSION_VERSION'}) ? $ENV{'KDE_SESSION_VERSION'} : '';
	# for fallback to fallback protections re false gnome id
	$gdmsession = ($ENV{'GDMSESSION'}) ? clean_env($ENV{'GDMSESSION'}) : '';
	main::feature_debugger('desktop-scalars',
	['$desktop_session: ' . $desktop_session,
	'$xdg_desktop: ' . $xdg_desktop,
	'$kde_full_session: ' . $kde_full_session,
	'$kde_session_version: ' . $kde_session_version,
	'$gdmsession: ' . $gdmsession],$dbg[63]) if $b_dbg_de;
}

# Note: an ubuntu regresssion replaces or adds 'ubuntu' string to 
# real value. Since ubuntu is the only distro I know that does this, 
# will add more distro type filters as/if we come across them
# args: 0: 
sub clean_env {
	$_[0] = lc(main::trimmer($_[0]));
	$_[0] =~ s/\b(arch|debian|fedora|manjaro|mint|opensuse|ubuntu):?\s*//i;
	return $_[0];
}

sub set_xprop {
	eval $start if $b_log;
	$loaded{'xprop'} = 1;
	my $data;
	if (my $program = main::check_program('xprop')){
		$data = main::grabber("xprop -root $display_opt 2>/dev/null",'','strip','ref');
		if ( @$data){
			my $pattern = '_(MIT|QT_DESKTOP|WIN|XROOTPMAP)_|_NET_(CLIENT|SUPPORTED)|';
			$pattern .= '(AT_SPI|ESETROOT|GDK_VISUALS|GNOME_SM|PULSE|RESOURCE_|XKLAVIER';
			@$data = grep {!/^($pattern))/} @$data;
		}
		if ($data && @$data){
			$_ = lc for @$data;
			# Add wm / de as required, but only add what is really tested for above
			# index: 0: PD full name; 1: xprop search; 2: PD version name
			my @info = (
			['amiwm','^amiwm',''],
			# leads to false IDs since other wm have this too
			# ['blackbox','blackbox_pid',''], # fluxbox, forked from blackbox, has this
			['bspwm','bspwm',''],
			['compiz','compiz',''],
			['enlightenment','enlightenment',''], # gets version from line
			['gnome-session','^_gnome_session',''],
			['herbstluftwm','herbstluftwm',''],
			['i3','^i3_',''],
			['icewm','icewm',''],
			['kde','^kde_','kwin'],
			['kwin','^kwin_',''],
			['marco','_marco',''],
			['moksha','moksha',''], # gets version from line
			# cde's dtwm is based on mwm, leads to bad ID, look for them with env/ps
			# ['motif','^_motif_wm','mwm'],
			['muffin','_muffin',''],
			['mutter','_mutter',''],
			['openbox','openbox_pid',''], # lxde, lxqt, razor _may_ have this
			['ukwm','^_ukwm',''],
			['windowmaker','^_?windowmaker','wmaker'],
			['wm2','^_wm2',''],
			# XFDESKTOP_IMAGE_FILE; XFCE_DESKTOP
			['xfce','^xfce','xfdesktop'],
			['xfdesktop','^xfdesktop',''],
			);
			foreach my $item (@info){
				foreach my $line (@$data){
					if ($line =~ /$item->[1]/){
						$xprop{$item->[0]} = {
						'name' => $item->[0],
						'vname' => $item->[2],
						} if !$xprop{$item->[0]};
						# we can have > 1 results for each search, and we want those lines
						push(@{$xprop{$item->[0]}->{'lines'}},$line);
					}
				}
			}
		}
	}
	main::feature_debugger('xprop data: working, results',
	[$data,\%xprop],$dbg[63]) if $b_dbg_de;
	eval $end if $b_log;
}
}

## DeviceData
# creates arrays: $devices{'audio'}; $devices{'graphics'}; $devices{'hwraid'}; 
# $devices{'network'}; $devices{'timer'} and local @devices for logging/debugging
# 0: type
# 1: type_id
# 2: bus_id
# 3: sub_id
# 4: device
# 5: vendor_id
# 6: chip_id
# 7: rev
# 8: port
# 9: driver
# 10: modules
# 11: driver_nu [bsd, like: em0 - driver em; nu 0. Used to match IF in -n
# 12: subsystem/vendor
# 13: subsystem vendor_id:chip id
# 14: soc handle
# 15: serial number
{