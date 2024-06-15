package PsData;

sub set {
	eval $start if $b_log;
	my ($b_busybox,$header,$ps,@temp);
	$loaded{'ps-data'} = 1;
	my $args = 'wwaux';
	my $path = main::check_program('ps');
	my $link = readlink($path);
	if ($link && $link =~ /busybox/i){
		$b_busybox = 1;
		$args = '';
	}
	# note: some ps cut output based on terminal width, ww sets width unlimited
	# old busybox returns error with args, new busybox ignores auxww
	$ps = main::grabber("$path $args 2>/dev/null",'','strip','ref');
	if (@$ps){
		$header = shift @$ps; # get rid of header row
		# handle busy box, which has 3 columns, regular ps aux has 11
		# avoid deprecated implicit split error in older Perls
		@temp = split(/\s+/, $header);
	}
	else {
		return;
	}
	$ps_data{'header'}->[0] = $#temp; # the indexes, not the scalar count
	for (my $i = 0; $i <= $#temp; $i++){
		if ($temp[$i] eq 'PID'){
			$ps_data{'header'}->[1] = $i;}
		elsif ($temp[$i] eq '%CPU'){
			$ps_data{'header'}->[2] = $i;}
		# note: %mem is percent used
		elsif ($temp[$i] eq '%MEM'){
			$ps_data{'header'}->[3] = $i;}
		elsif ($temp[$i] eq 'RSS'){
			$ps_data{'header'}->[4] = $i;}
	}
	# we want more data from ps busybox, to get TinyX screen res
	my $cols_use = ($b_busybox) ? 7 : 2;
	my $pattern = 'brave|chrom(e|ium)|falkon|(fire|water)fox|gvfs|';
	$pattern .= 'konqueror|mariadb|midori|mysql|openvpn|opera|';
	$pattern .= 'pale|postgre|php|qtwebengine|smtp|vivald';
	for (@$ps){
		next if !$_;
		next if $self_name eq 'inxi' && /\/$self_name\b/;
		# $_ = lc;
		push (@ps_aux,$_);
		my @split = split(/\s+/, $_);
		# slice out COMMAND to last elements of psrows
		my $final = $#split;
		# some stuff has a lot of data, chrome for example
		$final = ($final > ($ps_data{'header'}->[0] + $cols_use)) ? 
			$ps_data{'header'}->[0] + $cols_use : $final;
		# handle case of ps wrapping lines despite ww unlimited width, which 
		# should NOT be happening, except on busybox ps, which has no ww.
		next if !defined $split[$ps_data{'header'}->[0]]; 
		# we don't want zombie/system/kernel processes, or servers, browsers.
		# but we do want network kernel process servers [nfsd]
		$split[$ps_data{'header'}->[0]] =~ s/^\[(mld|nfsd)\]/$1/;
		if ($split[$ps_data{'header'}->[0]] !~ /^([\[\(]|(\S+\/|)($pattern))/i){
			push(@ps_cmd,join(' ', @split[$ps_data{'header'}->[0] .. $final]));
		}
	}
	# dump multiple instances, just need to see if process running
	main::uniq(\@ps_cmd) if @ps_cmd;
	# Use $dbg[61] to see @ps_cmd result
	eval $end if $b_log;
}

# only runs when no /run type dm found
sub set_dm {
	eval $start if $b_log;
	# startx: /bin/sh /usr/bin/startx
	process_items(\@{$ps_data{'dm-active'}},join('|',qw(ly startx xinit))); # possible dm values
	print '$ps_data{dm-active}: ', Data::Dumper::Dumper $ps_data{'dm-active'} if $dbg[5];
	main::log_data('dump','$ps_data{dm-active}',$ps_data{'dm-active'}) if $b_log;
	eval $end if $b_log;
}

sub set_de_wm {
	eval $start if $b_log;
	$loaded{'ps-gui'} = 1;
	my ($b_de_wm_comp,$b_wm_comp);
	# desktops / wm (some wm also compositors)
	if ($show{'system'}){
		# some desktops detect via ps as fallback
		process_items(\@{$ps_data{'de-ps-detect'}},join('|', qw(
		razor-desktop razor-session lxsession lxqt-session nscde
		tdelauncher tdeinit_phase1)));
		# order matters!
		process_items(\@{$ps_data{'wm-parent'}},join('|', qw(xfdesktop icewm fluxbox 
		blackbox)));
		# regular wm
		# unverfied: 2bwm catwm mcwm penrose snapwm uwm wmfs wmfs2 wingo wmii2
		process_items(\@{$ps_data{'wm-main'}},join('|', qw(2bwm 9wm 
		afterstep aewm aewm\+\+ amiwm antiwm awesome
		bspwm calmwm catwm cde clfswm ctwm (openbsd-)?cwm 
		dawn dtwm dusk dwm echinus evilwm flwm flwm_topside 
		fvwm.*-crystal\S* fvwm1 fvwm2 fvwm3 fvwm95 fvwm
		hackedbox herbstluftwm i3 instantwm ion3 jbwm jwm larswm leftwm lwm 
		matchbox-window-manager mcwm mini miwm mlvwm monsterwm musca mvwm mwm 
		nawm notion openbox nscde pekwm penrose qvwm ratpoison 
		sapphire sawfish scrotwm snapwm spectrwm stumpwm subtle tinywm tvtwm twm 
		uwm vtwm windowlab [wW]indo[mM]aker w9wm wingo wm2 wmfs wmfs2 wmii2 wmii 
		wmx x9wm xmonad yeahwm)));
		$b_wm_comp = 1;
		# wm: note that for all but the listed wm, the wm and desktop would be the 
		# same, particularly with all smaller wayland wm/compositors.
		$b_de_wm_comp = 1 if $extra > 1;
	}
	# compositors (for wayland these are also the server, note).
	# for wayland always show, so always load these
	if ($show{'graphic'}){
		$b_de_wm_comp = 1;
		$b_wm_comp = 1;
		process_items(\@{$ps_data{'compositors-pure'}},join('|',qw(cairo compton dcompmgr 
		mcompositor picom steamcompmgr surfaceflinger xcompmgr unagi)));
	}
	if ($b_de_wm_comp){
		process_items(\@{$ps_data{'de-wm-compositors'}},join('|',qw(budgie-wm compiz 
		deepin-kwin_wayland deepin-kwin_x11 deepin-wm enlightenment gala gnome-shell 
		twin kwin_wayland kwin_x11 kwinft kwin marco deepin-metacity metacity 
		metisse mir moksha muffin deepin-mutter mutter ukwm xfwm[345]?)));
	}
	if ($b_wm_comp){
		# x11: 3dwm, qtile [originally], rest wayland
		# wayland compositors generally are compositors and wm. 
		# These will be used globally to avoid having to redo it over and over.
		process_items(\@{$ps_data{'wm-compositors'}},join('|',qw(3dwm asc awc bismuth
		cage cagebreak cardboard chameleonwm clayland comfc 
		dwl dwc epd-wm fireplace feathers fenestra glass gamescope greenfield grefson 
		hikari hopalong [Hh]yprland inaban japokwm kiwmi labwc laikawm lipstick liri 
		mahogany marina maze maynard motorcar newm nucleus 
		orbital orbment perceptia phoc polonium pywm qtile river rootston rustland 
		simulavr skylight smithay sommelier sway swayfx swc swvkc 
		tabby taiwins tinybox tinywl trinkster velox vimway vivarium 
		wavy waybox way-?cooler wayfire wayhouse waymonad westeros westford 
		weston wio\+? wxr[cd] xuake)));
	}
	# info:/tools: 
	if ($show{'system'} && $extra > 2){
		process_items(\@{$ps_data{'components-active'}},join('|', qw(
		albert alltray awesomebar awn 
		bar barpanel bbdock bbpager bemenu bipolarbar bmpanel bmpanel2 budgie-panel 
		cairo-dock dde-dock deskmenu dmenu(-wayland)? dockbarx docker docky dzen dzen2 
		fbpanel fspanel fuzzel glx-dock gnome-panel hpanel 
		i3bar i3-status(-rs|-rust)? icewmtray jgmenu kdocker kicker krunner ksmoothdock
		latte lavalauncher latte-dock lemonbar ltpanel luastatus lxpanel lxqt-panel 
		matchbox-panel mate-panel mauncher mopag nwg-(bar|dock|launchers|panel) 
		openbox-menu ourico perlpanel plank polybar pypanel razor(qt)?-panel rofi rootbar 
		sfwbar simplepanel sirula some_sorta_bar stalonetray swaybar 
		taffybar taskbar tint2 tofi trayer ukui-panel vala-panel 
		wapanel waybar wbar wharf wingpanel witray wldash wmdocker wmsystemtray wofi 
		xfce[45]?-panel xmobar yambar yabar yofi)));
		# Generate tools: power manager daemons, then screensavers/lockers. 
		# Note that many lockers may not be services
		@{$ps_data{'tools-test'}}=qw(away boinc-screensaver budgie-screensaver 
		cinnamon-screensaver gnome-screensaver gsd-screensaver-proxy gtklock 
		hyprlock i3lock kscreenlocker light-locker lockscreen lxlock 
		mate-screensaver nwg-lock 
		physlock rss-glx slock swayidle swaylock ukui-screensaver unicode-screensaver 
		xautolock xfce4-screensaver xlock xlockmore xscreensaver 
		xscreensaver-systemd xsecurelock xss-lock xtrlock);
		process_items(\@{$ps_data{'tools-active'}},join('|',@{$ps_data{'tools-test'}}));
	}
	if ($dbg[63]){
		main::feature_debugger('ps de-wm',
		['compositors-pure:',$ps_data{'compositors-pure'},
		'de-ps-detect:',$ps_data{'de-ps-detect'},
		'de-wm-compositors:',$ps_data{'de-wm-compositors'},
		'wm-main:',$ps_data{'wm-main'},
		'wm-parent:',$ps_data{'wm-parent'},
		'wm-compositors:',$ps_data{'wm-compositors'}],$dbg[63]);
	}
	print '%ps_data: ', Data::Dumper::Dumper \%ps_data if $dbg[5];
	main::log_data('dump','%ps_data',\%ps_data) if $b_log;
	eval $end if $b_log;
}

sub set_network {
	eval $start if $b_log;
	process_items(\@{$ps_data{'network-services'}},join('|', qw(apache\d? 
	cC]onn[mM]and? dhcpd dhcpleased fingerd ftpd gated httpd inetd ircd iwd 
	mld [mM]odem[mM]nager named networkd-dispatcher [nN]etwork[mM]anager nfsd nginx 
	ntpd proftpd routed smbd sshd systemd-networkd systemd-timesyncd tftpd 
	wicd wpa_supplicant xinetd xntpd)));
	print '$ps_data{network-daemons}: ', Data::Dumper::Dumper $ps_data{'network-services'} if $dbg[5];
	main::log_data('dump','$ps_data{network-daemons}',$ps_data{'network-services'}) if $b_log;
	eval $end if $b_log;
}

sub set_power {
	eval $start if $b_log;
	process_items(\@{$ps_data{'power-services'}},join('|', qw(apmd csd-power
	gnome-power-manager gsd-power kpowersave org\.dracolinux\.power
	org_kde_powerdevil mate-power-manager power-profiles-daemon powersaved 
	tdepowersave thermald tlp upowerd ukui-power-manager xfce4-power-manager)));
	print '$ps_data{power-daemons}: ', Data::Dumper::Dumper $ps_data{'power-services'} if $dbg[5];
	main::log_data('dump','$ps_data{power-daemons}',$ps_data{'power-services'}) if $b_log;
	eval $end if $b_log;
}

# args: 0: array ref or scalar to become ref; 1: 1: matches pattern
sub process_items {
	foreach (@ps_cmd){
		# strip out python/lisp/*sh starters 
		if (/^(\/\S+?\/(c?lisp|perl|python|[a-z]{0,3}sh)\s+)?(|\S*?\/)($_[1])(:|\s|$)/i){
			push(@{$_[0]},$4) ; # deal with duplicates with uniq
		}
	}
	main::uniq($_[0]) if @{$_[0]} && scalar @{$_[0]} > 1;
}
}

sub get_self_version {
	eval $start if $b_log;
	my $patch = $self_patch;
	if ($patch ne ''){
		# for cases where it was for example: 00-b1 clean to -b1
		$patch =~ s/^[0]+-?//;
		$patch = "-$patch" if $patch;
	}
	eval $end if $b_log;
	return $self_version . $patch;
}

## ServiceData
{