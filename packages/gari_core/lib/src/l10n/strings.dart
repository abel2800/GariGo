class S {
  S(this.isAm);
  final bool isAm;
  factory S.of(bool isAmharic) => S(isAmharic);

  String get appName => 'GariGo';
  String get continueLabel => isAm ? 'ቀጥል' : 'Continue';
  String get cancel => isAm ? 'ሰርዝ' : 'Cancel';
  String get accept => isAm ? 'ተቀበል' : 'Accept';
  String get decline => isAm ? 'አትቀበል' : 'Decline';
  String get home => isAm ? 'መነሻ' : 'Home';
  String get history => isAm ? 'እንቅስቃሴ' : 'Activity';
  String get activity => isAm ? 'እንቅስቃሴ' : 'Activity';
  String get wallet => isAm ? 'ዋሌት' : 'Wallet';
  String get profile => isAm ? 'መገለጫ' : 'Profile';
  String get chooseRide => isAm ? 'ጉዞ ይምረጡ' : 'Choose a ride';
  String get confirmRide => isAm ? 'አረጋግጥ' : 'Confirm';
  String get firstRidePromo =>
      isAm ? '50 ብር ቅናሽ ለመጀመሪያ ጉዞ' : '50 Br off your first ride';
  String get tripCompleted => isAm ? 'ጉዞ ተጠናቋል' : 'Trip completed';
  String get howWasTrip => isAm ? 'ጉዞዎ እንዴት ነበር?' : 'How was your trip';
  String get done => isAm ? 'ተጠናቋል' : 'Done';
  String get noTip => isAm ? 'ቲፕ የለም' : 'No tip';
  String get untilPickup => isAm ? 'እስከ ማንሳት' : 'until pickup';
  String get tripFare => isAm ? 'የጉዞ ክፍያ' : 'trip fare';
  String get cancelTrip => isAm ? 'ጉዞ ሰርዝ' : 'Cancel trip';
  String get mobileNumber => isAm ? 'የስልክ ቁጥር' : 'Mobile number';
  String get riderHero =>
      isAm ? 'አዲስ፣ ጉዞዎ በ2 ደቂቃ ውስጥ ነው።' : 'Addis, your ride is 2 minutes away.';
  String get earnings => isAm ? 'ገቢ' : 'Earnings';
  String get announcements => isAm ? 'ማስታወቂያዎች' : 'Announcements';
  String get support => isAm ? 'ድጋፍ' : 'Support';
  String get phoneHint => isAm ? 'የስልክ ቁጥር' : 'Phone number';
  String get enterOtp => isAm ? 'ኮድ ያስገቡ' : 'Enter verification code';
  String get resend => isAm ? 'እንደገና ላክ' : 'Resend code';
  String get terms => isAm
      ? 'በመቀጠል የጋሪጎን ውሎች እና የግላዊነት ፖሊሲ ይቀበላሉ'
      : "By continuing you agree to GariGo's Terms and Privacy Policy";
  String get termsPrefix =>
      isAm ? 'በመቀጠል የጋሪጎን ' : "By continuing you agree to GariGo's ";
  String get termsLink => isAm ? 'ውሎች' : 'Terms';
  String get privacyLink => isAm ? 'የግላዊነት ፖሊሲ' : 'Privacy Policy';
  String get termsAnd => isAm ? ' እና ' : ' and ';
  String get readyToEarn => isAm ? 'ለማግኘት ዝግጁ?' : 'Ready to earn?';
  String get signInDriverId => isAm
      ? 'ኦንላይን ለመሆን በሹፌር መታወቂያዎ ይግቡ።'
      : 'Sign in with your driver ID to go online.';
  String get driverIdOrPhone =>
      isAm ? 'የሹፌር መታወቂያ ወይም ስልክ' : 'Driver ID or phone number';
  String get pinHint => isAm ? 'ፒን / ኦቲፒ' : 'PIN';
  String get applyToDrive => isAm ? 'ለመንዳት ያመልክቱ' : 'Apply to drive';
  String get newDriver => isAm ? 'አዲስ ሹፌር?' : 'New driver?';
  String get liveInAddis => isAm ? 'በአዲስ አበባ ቀጥታ' : 'Live in Addis';
  String get invalidPhone =>
      isAm ? 'ልክ ያልሆነ የኢትዮጵያ ስልክ ቁጥር' : 'Invalid Ethiopian mobile number';
  String get invalidOtp => isAm ? 'ልክ ያልሆነ ኮድ' : 'Invalid code';
  String get chooseLanguage => isAm ? 'ቋንቋ ይምረጡ' : 'Choose your language';
  String get tagline => 'ጋሪዎን ይምረጡ · Choose your ride';
  String get whereTo => isAm ? 'የት?' : 'Where to?';
  String get confirmDestination =>
      isAm ? 'መድረሻ አረጋግጥ' : 'Confirm Destination';
  String get choosePayment => isAm ? 'ክፍያ ይምረጡ' : 'Choose Payment';
  String get findingDriver =>
      isAm ? 'ሹፌርዎን በመፈለግ ላይ…' : 'Finding your driver…';
  String get showPin =>
      isAm ? 'ይህን ኮድ ለሹፌሩ ያሳዩ' : 'Show this code to your driver';
  String get shareTrip => isAm ? 'ጉዞ አጋራ' : 'Share Trip Status';
  String get rateTrip => isAm ? 'ደረጃ ይስጡ' : 'Rate your trip';
  String get goOnline => isAm ? 'ኦንላይን ይሁኑ' : 'Go Online';
  String get trips => isAm ? 'ጉዞዎች' : 'Trips';
  String get youreOffline => isAm ? 'ኦፍላይን ነዎት' : "You're offline";
  String get youreOnline => isAm ? 'ኦንላይን ነዎት' : "You're online";
  String get tapToGoOnline =>
      isAm ? 'ኦንላይን ለመሆን ይንኩ' : 'Tap to go online';
  String get searchingTrips =>
      isAm ? 'ጉዞ በመፈለግ ላይ…' : 'Searching for trips…';
  String get stayBusyAreas => isAm
      ? 'ፈጣን ጥያቄ ለማግኘት በተጨናነቀ ቦታ ይቆዩ'
      : 'Stay near busy areas for faster requests';
  String get newTripRequest => isAm ? 'አዲስ ጉዞ ጥያቄ' : 'New trip request';
  String get acceptTrip => isAm ? 'ጉዞ ተቀበል' : 'Accept trip';
  String get swipeArrived =>
      isAm ? 'ሲደርሱ ይጥረጉ' : 'Swipe when arrived';
  String get availableCashOut =>
      isAm ? 'ለማውጣት ዝግጁ' : 'Available to cash out';
  String get tripHistory => isAm ? 'የጉዞ ታሪክ' : 'Trip history';
  String get startTrip => isAm ? 'ጉዞ ጀምር' : 'Start Trip';
  String get endTrip => isAm ? 'ጉዞ ጨርስ' : 'End Trip';
  String get iveArrived => isAm ? 'ደርሻለሁ' : "I've Arrived";
  String get askPin =>
      isAm ? 'ከተሳፋሪው የ4 አሃዝ ኮድ ይጠይቁ' : 'Ask the rider for their 4-digit code';
  String get cashOut => isAm ? 'ገንዘብ አውጣ' : 'Cash out';
  String get todayEarnings => isAm ? 'የዛሬ ገቢ' : "Today's earnings";
  String get logout => isAm ? 'ውጣ' : 'Log out';
  String get guestContinue =>
      isAm ? 'እንደ እንግዳ ቀጥል' : 'Continue as Guest';
  String get demoOtp => 'Demo OTP: 123456';
  String get sosConfirm => isAm
      ? 'SOS ወደ ጋሪጎ ኮማንድ ሴንተር ይላክ?'
      : 'Send SOS to GariGo Command Center?';
  String get sendSos => isAm ? 'SOS ላክ' : 'Send SOS';
  String get backHome => isAm ? 'ወደ መነሻ' : 'Back to Home';
  String get skip => isAm ? 'ዝለል' : 'Skip';
}
