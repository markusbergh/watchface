using Toybox.Application as App;
using Toybox.Position as Position;

class ConnectIQApp extends App.AppBase {

	var connectIQView = null;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
    		//Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    		//Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }
    
    function onPosition(info) {
        connectIQView.setPosition(info);
    }

    // Return the initial view of your application here
    function getInitialView() {
    		connectIQView = new ConnectIQView();
        return [ connectIQView ];
    }

}