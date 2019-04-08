//////////////////////////////////////////////////////////////////////
//
// Geolocation.js
// JavaScript runtime code for Elm PortFunnel.Geolocation module.
// Copyright (c) 2018-2019 Bill St. Clair <billstclair@gmail.com>
// Portions Copyright (c) 2015-2016, Evan Czaplicki
// All rights reserved.
// Distributed under the BSD-3-Clause License
// See LICENSE
//
//////////////////////////////////////////////////////////////////////

(function(scope) {
  var moduleName = 'Geolocation';
  var sub;

  function init() {
    var PortFunnel = scope.PortFunnel;
    if (!PortFunnel || !PortFunnel.sub || !PortFunnel.modules) {
      // Loop until PortFunnel.js has initialized itself.
      setTimeout(init, 10);
      return;
    }
    
    sub = PortFunnel.sub;
    PortFunnel.modules[moduleName] = { cmd: dispatcher };

    // Let the Elm code know we've started
    sub.send({ module: moduleName,
               tag: "startup",
               args : null
             });
  }
  init();

  function sendObject(tag, args) {
    sub.send({ module: moduleName,
               tag: tag,
               args: args
             });
  }


  // Elm command dispatching

  var tagTable =
      { getlocation: getLocation,
        sendchanges: sendChanges,
        stopchanges: stopChanges
      }

  function dispatcher(tag, args) {
    let f = tagTable[tag];
    if (f) {
      return f(args);
    }
  }

  function getLocation(args) {
    function onError(rawError) {
      var err = encodeError(rawError);
      sendObject("error", err);
    }
    var options = args;
    navigator.geolocation.getCurrentPosition(
      sendPosition, onError, rawOptions(options));
  }

  var watching = false;
  var watchid = null;

  function sendChanges(args) {
    if (!watching) {
      watchid = navigator.geolocation.watchPosition(sendPosition);
      watching = true;
    }
  }

  function stopChanges(args) {
    if (watching) {
      watching = false;
      navigator.geolocation.clearWatch(watchid);
    }
  }


  // Send a position through the subscription port

  function sendPosition(rawPosition) {
    var location = encodeLocation(rawPosition);
    sendObject("location", location);
  }


  // OPTIONS

  var defaultOptions =
      { enableHighAccuracy: false,
        timeout: undefined,
        maximumAge: 0
      }

  function rawOptions(options) {
    if (!options) {
      // For debugging. The Elm code always passes options.
      return defaultOptions;
    } else {
	  return { enableHighAccuracy: options.enableHighAccuracy,
	           timeout: options.timeout || undefined,
	           maximumAge: options.maximumAge || 0
	         };
    }
  }


  // LOCATIONS

  function encodeLocation(rawPosition) {
	var coords = rawPosition.coords;

	var rawAltitude = coords.altitude;
	var rawAccuracy = coords.altitudeAccuracy;
	var altitude =
		(rawAltitude === null || rawAccuracy === null)
		? null
		: { value: rawAltitude,
            accuracy: rawAccuracy
          };
	var heading = coords.heading;
	var speed = coords.speed;
	var movement =
		(heading === null || speed === null)
		? null
		: (speed === 0
		   ? 'static'
	       : { speed: speed, degreesFromNorth: heading }
          );
  	return { latitude: coords.latitude,
		     longitude: coords.longitude,
		     accuracy: coords.accuracy,
		     altitude: altitude,
		     movement: movement,
		     timestamp: rawPosition.timestamp
	       };
  }


  // ERRORS

  var errorTypes = ['PermissionDenied', 'PositionUnavailable', 'Timeout'];

  function encodeError(rawError) {
    var key = errorTypes[rawError.code - 1];
    var res = {};
    res[key] = rawError.message
    return res;
  }

})(this);
