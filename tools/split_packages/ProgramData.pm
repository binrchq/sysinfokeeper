package ProgramData;
my $output;

# returns array of: 0: program print name 1: program version
# args: 0: program values ID [usually program name]; 
# 1: program alternate name, or path [allows for running different command];
# 2: $extra level. Note that StartClient runs BEFORE -x levels are set!;
# 3: [array ref/undef] return full version output block
# Only use this function when you only need the name/version data returned
sub full {
	eval $start if $b_log;
	my ($values_id,$version_id,$level,$b_return_full) = @_;
	my @full;
	$level = 0 if !$level;
	# print "val_id: $values_id ver_id:$version_id lev:$level ex:$extra\n";
	ProgramData::set_values() if !$loaded{'program-values'};
	$version_id = $values_id if !$version_id;
	if (my $values = $program_values{$values_id}){
		$full[0] = $values->[3];
		# programs that have no version method return 0 0 for index 1 and 2
		if ($extra >= $level && $values->[1] && $values->[2]){
			$full[1] = version($version_id,$values->[0],$values->[1],$values->[2],
			$values->[5],$values->[6],$values->[7],$values->[8]);
		}
	}
	# should never trip since program should be whitelist, but mistakes happen!
	$full[0] ||= $values_id;
	$full[1] ||= '';
	$full[2] = $output if $b_return_full;
	eval $end if $b_log;
	return @full;
}

# It's almost 1000 times slower to load these each time values() is called!!
# %program_values: key: desktop/app command for --version => [0: search string; 
# 1: space print number; 2: [optional] version arg: -v, version, etc;
# 3: print name; 4: console 0/1; 
# 5: [optional] exit first line 0/1 [alt: if version=file replace value with \s]; 
# 6: [optional] 0/1 stderr output; 7: replace regex; 8: extra data]
sub set_values {
	$loaded{'program-values'} = 1;
	%program_values = (
	## Clients (IRC,chat) ##
	'bitchx' => ['bitchx',2,'','BitchX',1,0,0,'',''],# special
	'finch' => ['finch',2,'-v','Finch',1,1,0,'',''],
	'gaim' => ['[0-9.]+',2,'-v','Gaim',0,1,0,'',''],
	'ircii' => ['[0-9.]+',3,'-v','ircII',1,1,0,'',''],
	'irssi' => ['irssi',2,'-v','Irssi',1,1,0,'',''],
	'irssi-text' => ['irssi',2,'-v','Irssi',1,1,0,'',''],
	'konversation' => ['konversation',2,'-v','Konversation',0,0,0,'',''],
	'kopete' => ['Kopete',2,'-v','Kopete',0,0,0,'',''],
	'ksirc' => ['KSirc',2,'-v','KSirc',0,0,0,'',''],
	'kvirc' => ['[0-9.]+',2,'-v','KVIrc',0,0,1,'',''], # special
	'pidgin' => ['[0-9.]+',2,'-v','Pidgin',0,1,0,'',''],
	'quassel' => ['',1,'-v','Quassel [M]',0,0,0,'',''], # special
	'quasselclient' => ['',1,'-v','Quassel',0,0,0,'',''],# special
	'quasselcore' => ['',1,'-v','Quassel (core)',0,0,0,'',''],# special
	'gribble' => ['^Supybot',2,'--version','Gribble',1,0,0,'',''],# special
	'limnoria' => ['^Supybot',2,'--version','Limnoria',1,0,0,'',''],# special
	'supybot' => ['^Supybot',2,'--version','Supybot',1,0,0,'',''],# special
	'weechat' => ['[0-9.]+',1,'-v','WeeChat',1,0,0,'',''],
	'weechat-curses' => ['[0-9.]+',1,'-v','WeeChat',1,0,0,'',''],
	'xchat-gnome' => ['[0-9.]+',2,'-v','X-Chat-Gnome',1,1,0,'',''],
	'xchat' => ['[0-9.]+',2,'-v','X-Chat',1,1,0,'',''],
	## Desktops / wm / compositors ##
	'2bwm' => ['^2bwm',0,'0','2bWM',0,1,0,'',''], # unverified/based on mcwm
	'3dwm' => ['^3dwm',0,'0','3Dwm',0,1,0,'',''], # unverified
	'5dwm' => ['^5dwm',0,'0','5Dwm',0,1,0,'',''], # unverified
	'9wm' => ['^9wm',3,'-version','9wm',0,1,0,'',''],
	'aewm' => ['^aewm',3,'--version','aewm',0,1,0,'',''],
	'aewm++' => ['^Version:',2,'-version','aewm++',0,1,0,'',''],
	'afterstep' => ['^afterstep',3,'--version','AfterStep',0,1,0,'',''],
	'amiwm' => ['^amiwm',0,'0','AmiWM',0,1,0,'',''], # no version
	'antiwm' => ['^antiwm',0,'0','AntiWM',0,1,0,'',''], # no version known
	'asc' => ['^asc',0,'0','asc',0,1,0,'',''],
	'awc' => ['^awc',0,'0','awc',0,1,0,'',''], # unverified
	'awesome' => ['^awesome',2,'--version','awesome',0,1,0,'',''],
	'beryl' => ['^beryl',0,'0','Beryl',0,1,0,'',''], # unverified; legacy
	'bismuth' => ['^bismuth',0,'0','Bismuth',0,1,0,'',''], # unverified
	'blackbox' => ['^Blackbox',2,'--version','Blackbox',0,1,0,'',''],
	'bspwm' => ['^\S',1,'-v','bspwm',0,1,0,'',''],
	'budgie-desktop' => ['^budgie-desktop',2,'--version','Budgie',0,1,0,'',''],
	'budgie-wm' => ['^budgie',0,'0','budgie-wm',0,1,0,'',''],
	'cage' => ['^cage',3,'-v','Cage',0,1,0,'',''], 
	'cagebreak' => ['^Cagebreak',3,'-v','Cagebreak',0,1,0,'',''],
	'calmwm' => ['^calmwm',0,'0','CalmWM',0,1,0,'',''], # unverified
	'cardboard' => ['^cardboard',0,'0','Cardboard',0,1,0,'',''], # unverified
	'catwm' => ['^catwm',0,'0','catwm',0,1,0,'',''], # unverified
	'cde' => ['^cde',0,'0','CDE',0,1,0,'',''], # unverified
	'chameleonwm' => ['^chameleon',0,'0','ChameleonWM',0,1,0,'',''], # unverified
	'cinnamon' => ['^cinnamon',2,'--version','Cinnamon',0,1,0,'',''],
	'clfswm' => ['^clsfwm',0,'0','clfswm',0,1,0,'',''], # no version
	'comfc' => ['^comfc',0,'0','comfc',0,1,0,'',''], # unverified
	'compiz' => ['^compiz',2,'--version','Compiz',0,1,0,'',''],
	'compton' => ['^\d',1,'--version','Compton',0,1,0,'',''],
	'cosmic-comp' => ['^cosmic-comp',0,'0','cosmic-comp',0,1,0,'',''], # unverified
	'ctwm' => ['^\S',1,'-version','ctwm',0,1,0,'',''],
	'cwm' => ['^cwm',0,'0','CWM',0,1,0,'',''], # no version
	'dawn' => ['^dawn',1,'-v','dawn',0,1,1,'^dawn-',''], # to stderr, not verified
	'dcompmgr' => ['^dcompmgr',0,'0','dcompmgr',0,1,0,'',''], # unverified
	'deepin' => ['^Version',2,'file','Deepin',0,100,'=','','/etc/deepin-version'], # special
	'deepin-kwin_wayland' => ['^deepin-kwin',2,'--version','deepin-kwin_wayland',0,1,0,'',''],#
	'deepin-kwin_x11' => ['^deepin-kwin',2,'--version','deepin-kwin_x11',0,1,0,'',''],#
	'deepin-metacity' => ['^metacity',2,'--version','Deepin-Metacity',0,1,0,'',''],
	'deepin-mutter' => ['^mutter',2,'--version','Deepin-Mutter',0,1,0,'',''],
	'deepin-wm' => ['^gala',0,'0','DeepinWM',0,1,0,'',''], # no version
	'draco' => ['^draco',0,'0','Draco',0,1,0,'',''], # no version
	'dusk' => ['^dusk',1,'-v','dusk',0,1,1,'^dusk-',''], # to stderr, not verified
	'dtwm' => ['^dtwm',0,'0','dtwm',0,1,0,'',''],# no version
	'dwc' => ['^dwc',0,'0','dwc',0,1,0,'',''], # unverified
	'dwl' => ['^dwl',1,'-v','dwl',0,1,0,'^dwl-',''], # assume same as dwm
	'dwm' => ['^dwm',1,'-v','dwm',0,1,1,'^dwm-',''],
	'echinus' => ['^echinus',1,'-v','echinus',0,1,1,'',''], # echinus-0.4.9 (c)...
	# only listed here for compositor values, version data comes from xprop
	'enlightenment' => ['^enlightenment',0,'0','Enlightenment',0,1,0,'',''], # no version. Starts new
	'epd-wm' => ['^epd-wm',0,'0','epd-wm',0,1,0,'',''], # unverified
	'evilwm' => ['evilwm',3,'-V','evilwm',0,1,0,'',''],# might use full path in match
	'feathers' => ['^feathers',0,'0','feathers',0,1,0,'',''], # unverified
	'fenestra' => ['^fenestra',0,'0','fenestra',0,1,0,'',''], # unverified
	'fireplace' => ['^fireplace',0,'0','fireplace',0,1,0,'',''], # unverified
	'fluxbox' => ['^fluxbox',2,'-v','Fluxbox',0,1,0,'',''],
	'flwm' => ['^flwm',0,'0','FLWM',0,0,1,'',''], # no version
	# openbsd changed: version string: [FVWM[[main] Fvwm.. sigh, and outputs to stderr. Why?
	'fvwm' => ['^fvwm',2,'-version','FVWM',0,1,0,'',''], 
	'fvwm1' => ['^Fvwm',3,'-version','FVWM1',0,1,1,'',''],
	'fvwm2' => ['^fvwm',2,'--version','FVWM2',0,1,0,'',''],
	'fvwm3' => ['^fvwm',2,'--version','FVWM3',0,1,0,'',''],
	'fvwm95' => ['^fvwm',2,'--version','FVWM95',0,1,1,'',''],
	# Note: first line can be: FVWM-Cystal starting... so always use fvwm --version
	'fvwm-crystal' => ['^fvwm',2,'--version','FVWM-Crystal',0,0,0,'',''], # for print name fvwm
	'gala' => ['^gala',2,'--version','gala',0,1,0,'',''], # pantheon wm: can be slow result
	'gamescope' => ['^gamescope',0,'0','Gamescope',0,1,0,'',''], # unverified
	'glass' => ['^glass',3,'-v','Glass',0,1,0,'',''], 
	'gnome' => ['^gnome',3,'--version','GNOME',0,1,0,'',''], # no version, print name
	'gnome-about' => ['^gnome',3,'--version','GNOME',0,1,0,'',''],
	'gnome-shell' => ['^gnome',3,'--version','gnome-shell',0,1,0,'',''],
	'greenfield' => ['^greenfield',0,'0','Greenfield',0,1,0,'',''], # unverified
	'grefson' => ['^grefson',0,'0','Grefson',0,1,0,'',''], # unverified
	'hackedbox' => ['^hackedbox',2,'-version','HackedBox',0,1,0,'',''], # unverified, assume blackbox
	# note, herbstluftwm when launched with full path returns full path in version string
	'herbstluftwm' => ['herbstluftwm',2,'--version','herbstluftwm',0,1,0,'',''],
	'hikari' => ['^hikari',0,'0','hikari',0,1,0,'',''], # unverified
	'hopalong' => ['^hopalong',0,'0','Hopalong',0,1,0,'',''], # unverified
	'hyprctl' => ['^Tag:',2,'version','Hyprland',0,0,0,'',''], # method to get hyprland version
	'hyprland' => ['^hyprland',0,'0','Hyprland',0,0,0,'',''], # uses hyprctl for version
	'i3' => ['^i3',3,'--version','i3',0,1,0,'',''],
	'icewm' => ['^icewm',2,'--version','IceWM',0,1,0,'',''],
	'inaban' => ['^inaban',0,'0','inaban',0,1,0,'',''], # unverified
	'instantwm' => ['^instantwm',1,'-v','instantWM',0,1,1,'^instantwm-?(instantos-?)?',''],
	'ion3' => ['^ion3',0,'--version','Ion3',0,1,0,'',''], # unverified; also shell called ion
	'japokwm' => ['^japokwm',0,'0','japokwm',0,1,0,'',''], # unverified
	'jbwm' => ['jbwm',3,'-v','JBWM',0,1,0,'',''], # might use full path in match
	'jwm' => ['^jwm',2,'-v','JWM',0,1,0,'',''],
	'kded' => ['^KDE( Development Platform)?:',2,'--version','KDE',0,0,0,'\sDevelopment Platform',''],
	'kded1' => ['^KDE( Development Platform)?:',2,'--version','KDE',0,0,0,'\sDevelopment Platform',''],
	'kded2' => ['^KDE( Development Platform)?:',2,'--version','KDE',0,0,0,'\sDevelopment Platform',''],
	'kded3' => ['^KDE( Development Platform)?:',2,'--version','KDE',0,0,0,'\sDevelopment Platform',''],
	'kded4' => ['^KDE( Development Platform)?:',2,'--version','KDE Plasma',0,0,0,'\sDevelopment Platform',''],
	'kdesktop-trinity' => ['^TDE:',2,'--version','TDE (Trinity)',0,0,0],
	'kiwmi' => ['^kwimi',0,'0','kiwmi',0,1,0,'',''], # unverified
	'ksmcon' => ['^ksmcon',0,'0','ksmcon',0,1,0,'',''],# no version
	'kwin' => ['^kwin',0,'0','kwin',0,1,0,'',''],# no version, same as kde
	'kwin-kde' => ['^kwin',2,'--version','KDE Plasma',0,1,0,'',''],# only for 5+, same as KDE version
	'kwin_wayland' => ['^kwin_wayland',0,'0','kwin_wayland',0,1,0,'',''],# no version, same as kde
	'kwin_x11' => ['^kwin_x11',0,'0','kwin_x11',0,1,0,'',''],# no version, same as kde
	'kwinft' => ['^kwinft',0,'0','KWinFT',0,1,0,'',''], # unverified
	'labwc' => ['^labwc',0,'0','LabWC',0,1,0,'',''], # unverified
	'laikawm' => ['^laikawm',0,'0','LaikaWM',0,1,0,'',''], # unverified
	'larswm' => ['^larswm',2,'-v','larswm',0,1,1,'',''],
	'leftwm' => ['^leftwm',0,'0','LeftWM',0,1,0,'',''],# no version, in CHANGELOG
	'liri' => ['^liri',0,'0','liri',0,1,0,'',''],
	'lipstick' => ['^lipstick',0,'0','Lipstick',0,1,0,'',''], # unverified
	'liri' => ['^liri',0,'0','liri',0,1,0,'',''], # unverified
	'lumina-desktop' => ['^\S',1,'--version','Lumina',0,1,1,'',''],
	'lwm' => ['^lwm',0,'0','lwm',0,1,0,'',''], # no version
	'lxpanel' => ['^lxpanel',2,'--version','LXDE',0,1,0,'',''],
	# command: lxqt-panel
	'lxqt-panel' => ['^lxqt-panel',2,'--version','LXQt',0,1,0,'',''],
	'lxqt-session' => ['^lxqt-session',2,'--version','LXQt',0,1,0,'',''],
	'lxqt-variant' => ['^lxqt-panel',0,'0','LXQt-Variant',0,1,0,'',''],
	'lxsession' => ['^lxsession',0,'0','lxsession',0,1,0,'',''],
	'mahogany' => ['^mahogany',0,'0','Mahogany',0,1,0,'',''], # unverified, from stumpwm
	'manokwari' => ['^manokwari',0,'0','Manokwari',0,1,0,'',''],
	'marina' => ['^marina',0,'0','Marina',0,1,0,'',''], # unverified
	'marco' => ['^marco',2,'--version','marco',0,1,0,'',''],
	'matchbox' => ['^matchbox',0,'0','Matchbox',0,1,0,'',''],
	'matchbox-window-manager' => ['^matchbox',2,'--help','Matchbox',0,0,0,'',''],
	'mate-about' => ['^MATE[[:space:]]DESKTOP',-1,'--version','MATE',0,1,0,'',''],
	# note, mate-session when launched with full path returns full path in version string
	'mate-session' => ['mate-session',-1,'--version','MATE',0,1,0,'',''], 
	'maynard' => ['^maynard',0,'0','maynard',0,1,0,'',''], # unverified
	'maze' => ['^maze',0,'0','Maze',0,1,0,'',''], # unverified
	'mcompositor' => ['^mcompositor',0,'0','MCompositor',0,1,0,'',''], # unverified
	'mcwm' => ['^mcwm',0,'0','mcwm',0,1,0,'',''], # unverified/see 2bwm
	'metacity' => ['^metacity',2,'--version','Metacity',0,1,0,'',''],
	'metisse' => ['^metisse',0,'0','metisse',0,1,0,'',''],
	'mini' => ['^Mini',5,'--version','Mini',0,1,0,'',''],
	'mir' => ['^mir',0,'0','mir',0,1,0,'',''],# unverified
	'miwm' => ['^miwm',0,'0','MIWM',0,1,0,'',''], # no version
	'mlvwm' => ['^mlvwm',3,'--version','MLVWM',0,1,1,'',''], 
	'moblin' => ['^moblin',0,'0','moblin',0,1,0,'',''],# unverified
	'moksha' => ['^\S',1,'-version','Moksha',0,1,0,'',''], # v: x.y.z
	'monsterwm' => ['^monsterwm',0,'0','monsterwm',0,1,0,'',''],# unverified
	'motorcar' => ['^motorcar',0,'0','motorcar',0,1,0,'',''],# unverified
	'muffin' => ['^mu(ffin|tter)',2,'--version','Muffin',0,1,0,'',''],
	'musca' => ['^musca',0,'-v','Musca',0,1,0,'',''], # unverified
	'mutter' => ['^mutter',2,'--version','Mutter',0,1,0,'',''],
	'mvwm' => ['^mvwm',0,'0','mvwm',0,1,0,'',''], # unverified
	'mwm' => ['^mwm',0,'0','MWM',0,1,0,'',''],# no version
	'nawm' => ['^nawm',0,'0','nawm',0,1,0,'',''],# unverified
	'newm' => ['^newm',0,'0','newm',0,1,0,'',''], # unverified
	'notion' => ['^.',1,'--version','Notion',0,1,0,'',''],
	'nscde' => ['^(fvwm|nscde)',2,'--version','NsCDE',0,1,0,'',''],
	'nucleus' => ['^nucleus',0,'0','Nucleus',0,1,0,'',''], # unverified
	'openbox' => ['^openbox',2,'--version','Openbox',0,1,0,'',''],
	'orbital' => ['^orbital',0,'0','Orbital',0,1,0,'',''],# unverified
	'orbment' => ['^orbment',0,'0','orbment',0,1,0,'',''], # unverified
	'pantheon' => ['^pantheon',0,'0','Pantheon',0,1,0,'',''],# no version
	'papyros' => ['^papyros',0,'0','papyros',0,1,0,'',''],# no version
	'pekwm' => ['^pekwm',3,'--version','PekWM',0,1,0,'',''],
	'penrose' => ['^penrose',0,'0','Penrose',0,1,0,'',''],# no version?
	'perceptia' => ['^perceptia',0,'0','perceptia',0,1,0,'',''],
	'phoc' => ['^phoc',0,'0','phoc',0,1,0,'',''], # unverified
	'picom' => ['^\S',1,'--version','Picom',0,1,0,'^v',''],
	'plasmashell' => ['^plasmashell',2,'--version','KDE Plasma',0,1,0,'',''],
	'polonium' => ['^polonium',0,'0','polonium',0,1,0,'',''], # unverified
	'pywm' => ['^pywm',0,'0','pywm',0,1,0,'',''], # unverified
	'qtile' => ['^',1,'--version','Qtile',0,1,0,'',''],
	'qvwm' => ['^qvwm',0,'0','qvwm',0,1,0,'',''], # unverified
	'razor-session' => ['^razor',0,'0','Razor-Qt',0,1,0,'',''],
	'ratpoison' => ['^ratpoison',2,'--version','Ratpoison',0,1,0,'',''],
	'river' => ['^river',0,'0','River',0,1,0,'',''], # unverified
	'rootston' => ['^rootston',0,'0','rootston',0,1,0,'',''], # unverified, wlroot ref
	'rustland' => ['^rustland',0,'0','rustland',0,1,0,'',''], # unverified
	'sapphire' => ['^version sapphire',3,'-version','sapphire',0,1,0,'',''],
	'sawfish' => ['^sawfish',3,'--version','Sawfish',0,1,0,'',''],
	'scrotwm' => ['^scrotwm',2,'-v','scrotwm',0,1,1,'welcome to scrotwm',''],
	'simulavr' => ['simulavr^',0,'0','SimulaVR',0,1,0,'',''], # unverified
	'skylight' => ['^skylight',0,'0','Skylight',0,1,0,'',''], # unverified
	'smithay' => ['^smithay',0,'0','Smithay',0,1,0,'',''], # unverified
	'sommelier' => ['^sommelier',0,'0','sommelier',0,1,0,'',''], # unverified
	'snapwm' => ['^snapwm',0,'0','snapwm',0,1,0,'',''], # unverified
	'spectrwm' => ['^spectrwm',2,'-v','spectrwm',0,1,1,'welcome to spectrwm',''],
	# out of stump, 2 --version, but in tries to start new wm instance endless hang
	'stumpwm' => ['^SBCL',0,'--version','StumpWM',0,1,0,'',''], # hangs when run in wm
	'subtle' => ['^subtle',2,'--version','subtle',0,1,0,'',''],
	'surfaceflinger' => ['surfaceflinger^',0,'0','SurfaceFlinger',0,1,0,'',''], # Android, unverified
	'sway' => ['^sway',3,'-v','Sway',0,1,0,'',''],
	'swayfx' => ['^swayfx',0,'0','SwayFX',0,1,0,'',''], # probably same as sway, unverified
	'swayfx' => ['^sway',3,'-v','SwayFX',0,1,0,'',''], # not sure if safe
	'swc' => ['^swc',0,'0','swc',0,1,0,'',''], # unverified
	'swvkc' => ['^swvkc',0,'0','swvkc',0,1,0,'',''], # unverified
	'tabby' => ['^tabby',0,'0','Tabby',0,1,0,'',''], # unverified
	'taiwins' => ['^taiwins',0,'0','taiwins',0,1,0,'',''], # unverified
	'tinybox' => ['^tinybox',0,'0','tinybox',0,1,0,'',''], # unverified
	'tinywl' => ['^tinywl',0,'0','TinyWL',0,1,0,'',''], # unverified
	'tinywm' => ['^tinywm',0,'0','TinyWM',0,1,0,'',''], # no version
	'trinkster' => ['^trinkster',0,'0','Trinkster',0,1,0,'',''], # unverified
	'tvtwm' => ['^tvtwm',0,'0','tvtwm',0,1,0,'',''], # unverified
	'twin' => ['^Twin:',2,'--version','Twin',0,0,0,'',''],
	'twm' => ['^twm',0,'0','TWM',0,1,0,'',''], # no version
	'ukui' => ['^ukui-session',2,'--version','UKUI',0,1,0,'',''],
	'ukwm' => ['^ukwm',2,'--version','ukwm',0,1,0,'',''],
	'unagi' => ['^\S',1,'--version','unagi',0,1,0,'',''],
	'unity' => ['^unity',2,'--version','Unity',0,1,0,'',''],
	'unity-system-compositor' => ['^unity-system-compositor',2,'--version',
	'unity-system-compositor (mir)',0,0,0,'',''],
	'uwm' => ['^uwm',0,'0','UWM',0,1,0,'',''], # unverified
	'velox' => ['^velox',0,'0','Velox',0,1,0,'',''], # unverified
	'vimway' => ['^vimway',0,'0','vimway',0,1,0,'',''], # unverified
	'vivarium' => ['^vivarium',0,'0','Vivarium',0,1,0,'',''], # unverified
	'vtwm' => ['^vtwm',0,'0','vtwm',0,1,0,'',''], # no version
	'w9wm' => ['^w9wm',3,'-version','w9wm',0,1,0,'',''], # fork of 9wm, unverified
	'wavy' => ['^wavy',0,'0','wavy',0,1,0,'',''], # unverified
	'waybox' => ['^way',0,'0','waybox',0,1,0,'',''], # unverified
	'waycooler' => ['^way',3,'--version','way-cooler',0,1,0,'',''],
	'way-cooler' => ['^way',3,'--version','way-cooler',0,1,0,'',''],
	'wayfire' => ['^\d',1,'--version','wayfire',0,1,0,'',''], # -version/--version
	'wayhouse' => ['^wayhouse',0,'0','wayhouse',0,1,0,'',''], # unverified
	'waymonad' => ['^waymonad',0,'0','waymonad',0,1,0,'',''], # unverified
	'westeros' => ['^westeros',0,'0','westeros',0,1,0,'',''], # unverified
	'westford' => ['^westford',0,'0','westford',0,1,0,'',''], # unverified
	'weston' => ['^weston',2,'--version','Weston',0,1,0,'',''], 
	'windowlab' => ['^windowlab',2,'-about','WindowLab',0,1,0,'',''],
	'windowmaker' => ['^Window\s*Maker',-1,'--version','WindowMaker',0,1,0,'',''], # uses wmaker
	'wingo' => ['^wingo',0,'0','Wingo',0,1,0,'',''], # unverified
	'wio' => ['^wio',0,'0','Wio',0,1,0,'',''], # unverified
	'wio' => ['^wio\+',0,'0','wio+',0,1,0,'',''], # unverified
	'wm2' => ['^wm2',0,'0','wm2',0,1,0,'',''], # no version
	'wmaker' => ['^Window\s*Maker',-1,'--version','WindowMaker',0,1,0,'',''],
	'wmfs' => ['^wmfs',0,'0','WMFS',0,1,0,'',''], # unverified
	'wmfs2' => ['^wmfs',0,'0','WMFS',0,1,0,'',''], # unverified
	'wmii' => ['^wmii',1,'-v','wmii',0,1,0,'^wmii[234]?-',''], # wmii is wmii3
	'wmii2' => ['^wmii2',1,'--version','wmii2',0,1,0,'^wmii[234]?-',''],
	'wmx' => ['^wmx',0,'0','wmx',0,1,0,'',''], # no version
	'wxrc' => ['^wx',0,'0','',0,1,0,'WXRC',''], # unverified
	'wxrd' => ['^wx',0,'0','',0,1,0,'WXRD',''], # unverified
	'x9wm' => ['^x9wm',3,'-version','x9wm',0,1,0,'',''], # fork of 9wm, unverified
	'xcompmgr' => ['^xcompmgr',0,'0','xcompmgr',0,1,0,'',''], # no version
	'xfce-panel' => ['^xfce-panel',2,'--version','Xfce',0,1,0,'',''],
	'xfce4-panel' => ['^xfce4-panel',2,'--version','Xfce',0,1,0,'',''],
	'xfce5-panel' => ['^xfce5-panel',2,'--version','Xfce',0,1,0,'',''],
	'xfdesktop' => ['xfdesktop\sversion',5,'--version','Xfce',0,1,0,'',''],
	# '        This is xfwm4 version 4.16.1 (revision 5f61a84ad) for Xfce 4.16'
	'xfwm' => ['xfwm[3-8]? version',5,'--version','xfwm',0,1,0,'^^\s+',''],# unverified
	'xfwm3' => ['xfwm3? version',5,'--version','xfwm3',0,1,0,'^^\s+',''], # unverified
	'xfwm4' => ['xfwm4? version',5,'--version','xfwm4',0,1,0,'^^\s+',''],
	'xfwm5' => ['xfwm5? version',5,'--version','xfwm5',0,1,0,'^^\s+',''], # unverified
	'xmonad' => ['^xmonad',2,'--version','XMonad',0,1,0,'',''],
	'xuake' => ['^xuake',0,'0','xuake',0,1,0,'',''], # unverified
	'yeahwm' => ['^yeahwm',0,'--version','YeahWM',0,1,0,'',''], # unverified
	## Desktop Toolkits/Frameworks ##
	'efl-version' => ['^\S',1,'--version','EFL',0,1,0,'',''], # any arg returns v
	'gtk-launch' => ['^\S',1,'--version','GTK',0,1,0,'',''],
	'kded-qt' => ['^Qt',2,'--version','Qt',0,0,0,'',''],
	# --version: kded5 5.110.0 (frameworks v, not kde)
	'kded5-frameworks' => ['^kded5',2,'--version','frameworks',0,1,0],
	'kded6-frameworks' => ['^kded6',2,'--version','frameworks',0,1,0],
	'kf-config-qt' => ['^^Qt',2,'--version','Qt',0,0,0,'',''],
	'qmake-qt' => ['^Using Qt version',4,'--version','Qt',0,0,0,'',''],
	'qtdiag-qt' => ['^qt',2,'--version','Qt',0,0,0,'',''],
	# command: xfdesktop
	'xfdesktop-gtk' => ['Built\swith\sGTK',4,'--version','Gtk',0,0,0,'',''],
	## Display/Login Managers (dm,lm) ##
	'brzdm' => ['^brzdm version',3,'-v','brzdm',0,1,0,'',''], # unverified, slim fork
	'cdm' => ['^cdm',0,'0','CDM',0,1,0,'',''],
	# might be xlogin, unknown output for -V
	'clogin' => ['^clogin',0,'-V','clogin',0,1,0,'',''], # unverified, cysco router
	'elogind' => ['^elogind',0,'0','elogind',0,1,0,'',''], # no version
	'emptty' => ['^emptty',0,'0','EMPTTY',0,1,0,'',''], # unverified
	'entranced' => ['^entrance',0,'0','Entrance',0,1,0,'',''],
	'gdm' => ['^gdm',2,'--version','GDM',0,1,0,'',''],
	'gdm3' => ['^gdm',2,'--version','GDM3',0,1,0,'',''],
	'greetd' => ['^greetd',0,'0','greetd',0,1,0,'',''], # no version
	'kdm' => ['^kdm',0,'0','KDM',0,1,0,'',''],
	'kdm3' => ['^kdm',0,'0','KDM',0,1,0,'',''],
	'kdmctl' => ['^kdm',0,'0','KDM',0,1,0,'',''],
	'ldm' => ['^ldm',0,'0','LDM',0,1,0,'',''],
	'lemurs' => ['^lemurs',0,'0','lemurs',0,1,0,'',''], # unverified
	'lightdm' => ['^lightdm',2,'--version','LightDM',0,1,1,'',''],
	'loginx' => ['^loginx',0,'0','loginx',0,1,0,'',''], # unverified
	'lxdm' => ['^lxdm',0,'0','LXDM',0,1,0,'',''],
	'ly' => ['^ly',3,'--version','Ly',0,1,0,'',''],
	'mdm' => ['^mdm',0,'0','MDM',0,1,0,'',''],
	'mlogind' => ['^mlogind',3,'-v','mlogind',0,1,0,'',''], # guess, unverified, BSD SLiM fork
	'nodm' => ['^nodm',0,'0','nodm',0,1,0,'',''],
	'pcdm' => ['^pcdm',0,'0','PCDM',0,1,0,'',''],
	'qingy' => ['^qingy',0,'0','qingy',0,1,0,'',''], # unverified
	'seatd' => ['^seatd',3,'-v','seatd',0,1,0,'',''],
	'sddm' => ['^sddm',0,'0','SDDM',0,1,0,'',''],
	'slim' => ['slim version',3,'-v','SLiM',0,1,0,'',''],
	'slimski' => ['slimski version',3,'-v','slimski',0,1,0,'',''], # slim fork
	'tbsm' => ['^tbsm',0,'0','tbsm',0,1,0,'',''], # unverified
	'tdm' => ['^tdm',0,'0','TDM',0,1,0,'',''], # could be consold-tdm or tizen dm
	'udm' => ['^udm',0,'0','udm',0,1,0,'',''],
	'wdm' => ['^wdm',0,'0','WINGs DM',0,1,0,'',''],
	'x3dm' => ['^x3dm',0,'0','X3DM',0,1,0,'',''], # unverified
	'xdm' => ['^xdm',0,'0','XDM',0,1,0,'',''],
	'xdmctl' => ['^xdm',0,'0','XDM',0,1,0,'',''],# opensuse/redhat may use this to start real dm
	'xenodm' => ['^xenodm',0,'0','xenodm',0,1,0,'',''],
	'xlogin' => ['^xlogin',0,'-V','xlogin',0,1,0,'',''], # unverified, cysco router
	## Shells - not checked: ion, eshell ##
	## See ShellData::shell_test() for unhandled but known shells
	'ash' => ['',3,'pkg','ash',1,0,0,'',''], # special; dash precursor
	'bash' => ['^GNU[[:space:]]bash',4,'--version','Bash',1,1,0,'',''],
	'busybox' => ['^busybox',0,'0','BusyBox',1,0,0,'',''], # unverified, hush/ash likely
	'cicada' => ['^\s*version',2,'cmd','cicada',1,1,0,'',''], # special
	'csh' => ['^tcsh',2,'--version','csh',1,1,0,'',''], # mapped to tcsh often
	'dash' => ['',3,'pkg','DASH',1,0,0,'',''], # no version, pkg query
	'elvish' => ['^\S',1,'--version','Elvish',1,0,0,'',''],
	'fish' => ['^fish',3,'--version','fish',1,0,0,'',''],
	'fizsh' => ['^fizsh',3,'--version','FIZSH',1,0,0,'',''],
	# ksh/lksh/loksh/mksh/posh//pdksh need to print their own $VERSION info
	'ksh' => ['^\S',1,'cmd','ksh',1,0,0,'^(Version|.*KSH)\s*',''], # special
	'ksh93' => ['^\S',1,'cmd','ksh93',1,0,0,'^(Version|.*KSH)\s*',''], # special
	'lksh' => ['^\S',1,'cmd','lksh',1,0,0,'^.*KSH\s*',''], # special
	'loksh' => ['^\S',1,'cmd','loksh',1,0,0,'^.*KSH\s*',''], # special
	'mksh' => ['^\S',1,'cmd','mksh',1,0,0,'^.*KSH\s*',''], # special
	'nash' => ['^nash',0,'0','Nash',1,0,0,'',''], # unverified; rc based [no version]
	'oh' => ['^oh',0,'0','Oh',1,0,0,'',''], # no version yet
	'oil' => ['^Oil',3,'--version','Oil',1,1,0,'',''], # could use cmd $OIL_SHELL
	'osh' => ['^osh',3,'--version','OSH',1,1,0,'',''], # precursor of oil
	'pdksh' => ['^\S',1,'cmd','pdksh',1,0,0,'^.*KSH\s*',''], # special, in  ksh family
	'posh' => ['^\S',1,'cmd','posh',1,0,0,'',''], # special, in ksh family
	'tcsh' => ['^tcsh',2,'--version','tcsh',1,1,0,'',''], # enhanced csh
	'xonsh' => ['^xonsh',1,'--version','xonsh',1,0,0,'^xonsh[\/-]',''], 
	'yash' => ['^Y',5,'--version','yash',1,0,0,'',''], 
	'zsh' => ['^zsh',2,'--version','Zsh',1,0,0,'',''],
	## Sound Servers ##
	'arts' => ['^artsd',2,'-v','aRts',0,1,0,'',''],
	'esound' => ['^Esound',3,'--version','EsounD',0,1,1,'',''],
	'jack' => ['^jackd',3,'--version','JACK',0,1,0,'',''],
	'nas' => ['^Network Audio',5,'-V','NAS',0,1,0,'',''],
	'pipewire' => ['^Compiled with libpipe',4,'--version','PipeWire',0,0,0,'',''],
	'pulseaudio' => ['^pulseaudio',2,'--version','PulseAudio',0,1,0,'',''],
	'roaraudio' => ['^roaraudio',0,'0','RoarAudio',0,1,0,'',''], # no version/unknown?
	## Tools: Compilers ##
	'clang' => ['clang',3,'--version','clang',1,1,0,'',''],
	# gcc (Debian 6.3.0-18) 6.3.0 20170516
	# gcc (GCC) 4.2.2 20070831 prerelease [FreeBSD]
	'gcc' => ['^gcc',2,'--version','GCC',1,0,0,'\([^\)]*\)',''],
	'gcc-apple' => ['Apple[[:space:]]LLVM',2,'--version','LLVM',1,0,0,'',''], # not used
	'zigcc' => ['zigcc',0,'0','zigcc',1,1,0,'',''], # unverified
	## Tools: Init ##
	'busybox' => ['busybox',2,'--help','BusyBox',0,1,1,'',''],
	# Dinit version 0.15.1. [ends .]
	'dinit' => ['^Dinit',3,'--version','Dinit',0,1,0,'',''],
	# version: Epoch Init System 1.0.1 "Sage"
	'epoch' => ['^Epoch',4,'version','Epoch',0,1,0,'',''],
	'finit' => ['^Finit',2,'-v','finit',0,1,0,'',''],
	# /sbin/openrc --version: openrc (OpenRC) 0.13
	'openrc' => ['^openrc',3,'--version','OpenRC',0,1,0,'',''],
	# /sbin/rc --version: rc (OpenRC) 0.11.8 (Gentoo Linux)
	'rc' => ['^rc',3,'--version','OpenRC',0,1,0,'',''],
	'shepherd' => ['^shepherd',4,'--version','Shepherd',0,1,0,'',''],
	'systemd' => ['^systemd',2,'--version','systemd',0,1,0,'',''],
	'upstart' => ['upstart',3,'--version','Upstart',0,1,0,'',''],
	## Tools: Miscellaneous ##
	'sudo' => ['^Sudo',3,'-V','Sudo',1,1,0,'',''], # sudo pre 1.7 does not have --version
	'udevadm' => ['^\d{3}',1,'--version','udevadm',0,1,0,'',''],
	## Tools: Package Managers ##
	'guix' => ['^guix',4,'--version','Guix',0,1,0,'',''], # used for distro ID
	);
}

# returns array of:
# 0: match string; 1: search word number; 2: version string [alt: file]; 
# 3: Print name; 4: console 0/1; 
# 5: 0/1 exit version loop at 1 [alt: if version=file replace value with \s]; 
# 6: 0/1 write to stderr [alt: if version=file, path for file];
# 7: replace regex for further cleanup; 8: extra data
# note: setting index 1 or 2 to 0 will trip flags to not do version
# args: 0: program lower case name
sub values {
	my @values;
	ProgramData::set_values() if !$loaded{'program-values'};
	if (defined $program_values{$_[0]}){
		@values = @{$program_values{$_[0]}};
	}
	# my $debug = Dumper \@values;
	main::log_data('dump','@values',\@values) if $b_log;
	return @values;
}

# args: 0: desktop/app command for --version; 1: search string; 
# 2: space print number; 3: [optional] version arg: -v, version, etc;
# 4: [optional] exit 1st line 0/1; 5: [optional] 0/1 stderr output;
# 6: replace regex; 7: extra data
sub version {
	eval $start if $b_log;
	my ($app,$search,$num,$version,$exit,$stderr,$replace,$extra) = @_;
	my ($b_no_space,$cmd,$line);
	my $version_nu = '';
	my $count = 0;
	my $app_name = $app;
	$output = ();
	$app_name =~ s%^.*/%%;
	# print "app: $app :: appname: $app_name\n";
	$exit ||= 100; # basically don't exit ever
	$version ||= '--version';
	# adjust to array index, not human readable
	$num-- if (defined $num && $num > 0);
	# konvi in particular doesn't like using $ENV{'PATH'} as set, so we need
	# to always assign the full path if it hasn't already been done
	if ($version ne 'file' && $app !~ /^\//){
		if (my $program = main::check_program($app)){
			$app = $program;
		}
		else {
			main::log_data('data',"$app not found in path.") if $b_log;
			return 0;
		}
	}
	if ($version eq 'file'){
		return 0 unless $extra && -r $extra;
		$output = main::reader($extra,'strip','ref');
		@$output = map {s/$stderr/ /;$_} @$output if $stderr; # $stderr is the splitter
		$cmd = '';
	}
	# These will mostly be shells that require running the shell command -c to get info data
	elsif ($version eq 'cmd'){
		($cmd,$b_no_space) = version_cmd($app,$app_name,$extra);
		return 0 if !$cmd;
	}
	# slow: use pkg manager to get version, avoid unless you really want version
	elsif ($version eq 'pkg'){
		($cmd,$search) = version_pkg($app_name);
		return 0 if !$cmd;
	}
	# note, some wm/apps send version info to stderr instead of stdout
	elsif ($stderr){
		$cmd = "$app $version 2>&1";
	}
	else {
		$cmd = "$app $version 2>/dev/null";
	}
	# special case, in rare instances version comes from file
	if ($version ne 'file'){
		$output = main::grabber($cmd,'','strip','ref');
	}
	if ($b_log){
		main::log_data('data',"version: $version num: $num search: $search command: $cmd");
		main::log_data('dump','output',$output);
	}
	if ($dbg[64]){
		print "::::::::::\nPD::version() cmd: $cmd\noutput:",Data::Dumper::Dumper $output;
	}
	# sample: dwm-5.8.2, ©.. etc, why no space? who knows. Also get rid of v in number string
	# xfce, and other, output has , in it, so dump all commas and parentheses
	if ($output && @$output){
		foreach (@$output){
			last if $count == $exit;
			if ($_ =~ /$search/i){
				# print "loop: $_ :: num: $num\n";
				$_ =~ s/$replace//i if $replace;
				$_ =~ s/\s/_/g if $b_no_space; # needed for some items with version > 1 word
				my @data = split(/\s+/, $_);
				$version_nu = $data[$num];
				last if !defined $version_nu;
				# some distros add their distro name before the version data, which 
				# breaks version detection. A quick fix attempt is to just add 1 to $num 
				# to get the next value.
				$version_nu = $data[$num+1] if $data[$num+1] && $version_nu =~ /version/i;
				$version_nu =~ s/(\([^)]+\)|,|"|\||\(|\)|\.$)//g if $version_nu;
				# trim off leading v but only when followed by a number
				$version_nu =~ s/^v([0-9])/$1/i if $version_nu; 
				# print "$version_nu\n";
				last;
			}
			$count++;
		}
	}
	main::log_data('data',"Program version: $version_nu") if $b_log;
	eval $end if $b_log;
	return $version_nu;
}
# print version('bash', 'bash', 4) . "\n";

# returns ($cmdd, $b_no_space)
# ksh: Version JM 93t+ 2010-03-05 [OR] Version A 2020.0.0
# mksh: @(#)MIRBSD KSH R56 2018/03/09; lksh/pdksh: @(#)LEGACY KSH R56 2018/03/09
# loksh: @(#)PD KSH v5.2.14 99/07/13.2; posh: 0.13.2
sub version_cmd {
	eval $start if $b_log;
	my ($app,$app_name,$extra) = @_;
	my @data = ('',0);
	if ($app_name eq 'cicada'){
		$data[0] = $app . ' -c "' . $extra . '" 2>/dev/null';}
	elsif ($app_name =~ /^(|l|lo|m|pd)ksh(93)?$/){
		$data[0] = $app . ' -c \'printf %s "$KSH_VERSION"\' 2>/dev/null';
		$data[1] = 1;}
	elsif ($app_name eq 'posh'){
		$data[0] =  $app . ' -c \'printf %s "$POSH_VERSION"\' 2>/dev/null'}
	# print "$data[0] :: $data[1]\n";
	eval $end if $b_log;
	return @data;
}

# returns $cmd, $search
sub version_pkg  {
	eval $start if $b_log;
	my ($app) = @_;
	my ($program,@data);
	# note: version $num is 3 in dpkg-query/pacman/rpm, which is convenient
	if ($program = main::check_program('dpkg-query')){
		$data[0] = "$program -W -f='\${Package}\tversion\t\${Version}\n' $app 2>/dev/null";
		$data[1] = "^$app\\b";
	}
	elsif ($program = main::check_program('pacman')){
		$data[0] = "$program -Q --info $app 2>/dev/null";
		$data[1] = '^Version';
	}
	elsif ($program = main::check_program('rpm')){
		$data[0] = "$program -qi --nodigest --nosignature $app 2>/dev/null";
		$data[1] = '^Version';
	}
	# print "$data[0] :: $data[1]\n";
	eval $end if $b_log;
	return @data;
}
}

## PsData
# public methods: 
# set(): sets @ps_aux, @ps_cmd
# set_dm(): sets $ps_data{'dm-active'}
# set_de_wm(): sets -S/-G de/wm/comp/tools items
# set_network(): sets -na network services
# set_power(): sets -I $ps_data{'power-services'}
{