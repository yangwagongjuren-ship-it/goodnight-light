class Words {
  const Words(this.zh);
  final bool zh;
  String pick(String en, String cn) => zh ? cn : en;
  String get title => pick('Goodnight Light', '晚安灯');
  String get tagline =>
      pick('A night light that slowly fades', '一盏会慢慢变暗的晚安灯');
  String get duration => pick('Fade duration', '渐暗时长');
  String get durationHint =>
      pick('Gently dim from the moment you begin.', '从开始的那一刻，慢慢变暗。');
  String get custom => pick('Custom', '自定义');
  String get minutes => pick('minutes', '分钟');
  String get hours => pick('hours', '小时');
  String get seconds => pick('seconds', '秒');
  String get nonzero =>
      pick('Choose a duration longer than zero.', '请选择大于零的时长。');
  String durationLabel(int total) {
    final h = total ~/ 3600;
    final m = total ~/ 60 % 60;
    final s = total % 60;
    final parts = <String>[
      if (h > 0) pick('$h h', '$h 小时'),
      if (m > 0) minuteLabel(m),
      if (s > 0 || total == 0) pick('$s sec', '$s 秒'),
    ];
    return parts.join(' ');
  }

  String minuteLabel(int n) => pick('$n min', '$n 分钟');
  String get brightness => pick('Starting brightness', '初始亮度');
  String get companion => pick(
    'No rush to fall asleep.\nThe night is lovely. Rest a while',
    '不用急着睡着\n夜很美，先躺一会儿',
  );
  String get storyTitle => pick('The story behind this light', '这盏灯的故事');
  String get story => pick(
    'At bedtime with my child, switching off the light left him afraid of the dark; leaving it on was too bright. Even with a small night light, he would often lie awake for a long time before falling asleep.\n\nSo I made this night light that slowly fades. A little light gives him time to get used to the dark; as it gently dims, it keeps him company as he drifts off to sleep.\n\nI hope this little light makes your nights a little more comfortable, too.',
    '陪孩子睡觉时，关了灯，他怕黑；留着灯，又太亮。换成小夜灯，他常常睁开眼，很久才能入睡。\n\n于是，我做了这盏会慢慢变暗的晚安灯。留一点光，给他一点适应黑暗的时间；慢慢变暗，陪他慢慢进入睡眠。\n\n希望这一点光，也能让你的夜晚舒服一些。',
  );
  String get brightnessHint =>
      pick('Set the brightness to whatever feels comfortable.', '调到你觉得舒服的亮度');
  String get completed => pick(
    'This night light has finished. Start again whenever you like.',
    '本次夜灯已结束。需要时可以重新开始。',
  );
  String get completedTap => pick(
    'Night light finished. Tap to return to settings.',
    '夜灯已结束，轻点屏幕即可返回设置。',
  );
  String get start => pick('Start fading', '开始渐暗');
  String get hint => pick(
    'Hold the screen for 3 seconds to reveal controls.',
    '运行中长按屏幕 3 秒，即可显示控制。',
  );
  String get stop => pick('Stop & return', '停止并返回');
  String get back => pick('Back to settings', '返回设置');
  String get remaining => pick('REMAINING', '剩余时间');
  String get cancel => pick('Cancel', '取消');
  String get done => pick('Done', '确定');
  String get introTitle => pick('Before you settle in', '开始之前');
  String get introBody => pick(
    'Your screen stays awake while the warm light fades. At the end it turns black, then your phone’s auto-lock takes over. Tap the finished black screen to return, or reopen the app to see the completion message.\n\nEnable automatic screen lock in your phone settings. “Never” and Always-On Display can keep the screen lit. LCD screens may retain a faint glow until they switch off.\n\nSwitching apps or locking restores your previous brightness. Time continues to pass: return before the deadline to continue the fade, or afterwards to see that it has finished. Force-closing the app ends the session. This is a comfort light, not a sleep treatment.',
    '渐暗期间，屏幕会保持唤醒。结束时画面变黑，再由手机的自动锁定设置控制息屏。结束后轻点黑屏即可返回；重新打开也会显示已结束。\n\n请在系统设置中开启自动锁定。“永不”或息屏显示可能让屏幕继续发光。LCD 屏幕在真正关闭前可能仍有微弱背光。\n\n切换应用或锁屏时，会恢复手机原亮度，时间继续计算。到时前回来继续渐暗，到时后回来显示已结束。强制关闭应用会结束计时。这是一盏陪伴灯，不是睡眠治疗工具。',
  );
  String get understand => pick('Got it', '知道了');
  String get about => pick('About & privacy', '关于与隐私');
  String get privacyPolicy => pick('Privacy policy', '隐私政策');
  String get privacy => pick(
    'Everything stays on your phone.\n\nThis app saves only your duration, brightness, language and whether you have read the introduction. It has no account, ads, analytics, tracking or network requests. Clear app data or uninstall to remove these preferences.\n\nEnable auto-lock and disable Always-On Display if needed. Hold the running light to stop; tap the finished black screen to return. Leaving the app restores your previous brightness.\n\nVersion 1.0.5',
    '所有设置都留在你的手机里。\n\n应用只保存时长、亮度、语言以及是否已阅读使用说明。不含账号、广告、统计、追踪或网络请求。清除应用数据或卸载即可删除这些设置。\n\n开启自动锁定，按需关闭息屏显示；运行中长按可停止，结束后轻点黑屏可返回。离开应用时会恢复手机原亮度。\n\n版本 1.0.5',
  );
  String get deviceError => pick(
    'Screen control failed. Stop and reopen the app; use your power button if the screen stays awake.',
    '屏幕控制失败。请停止并重新打开应用；若屏幕保持唤醒，可按电源键锁屏。',
  );
  String get saveError => pick(
    'Could not save preferences. You can still use the light.',
    '设置未能保存，仍可使用夜灯。',
  );
  String get loadError => pick(
    'Could not load preferences. Default settings are shown.',
    '未能读取设置，已显示默认设置。',
  );
}
