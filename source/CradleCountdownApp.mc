using Toybox.WatchUi as Ui;

class CradleCountdownApp extends Toybox.Application.AppBase {
	hidden var CC;
	function initialize() {
		AppBase.initialize();
	}

	function onStart(state) {
	}

	function onStop(state) {
	}

	function getInitialView() {
		CC = new CradleCountdownView();
		
		if( Toybox.WatchUi.WatchFace has :onPartialUpdate ) {
        	return [ CC, new underlordCountdownDelegate()];
        } else {
        	return [ CC ];
        }  
	}

	function onSettingsChanged() {
		CC.onSettingsChanged();
	}

}
