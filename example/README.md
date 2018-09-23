# Geolocation Example

This directory contains an example of using the `PortFunnel.Geolocation` module. To run it in simulation mode:

```bash
$ git clone git@github.com:billstclair/elm-geolocation.git
$ cd elm-geolocation/example
$ elm reactor
```

Then aim your web browser at http://localhost:8000/Main.elm. This will report the same location every time; the simulator isn't very smart.

To run it using the port JavaScript, to get real location information, start it up as above, but aim your browser at http://localhost:8000/site/index.html.

See `Main.elm` for an example of how to use the `PortFunnel.Geolocation` module. You need to set up your site directory much as the `site` directory is set up here, with an `index.html` that includes your compiled Elm JavaScript file (`elm.js` here), with the files `js/PortFunnel.js` and `js/PortFunnel/Geolocation.js` as they are here, and with code similar to the following to start it up:

```javascript
var mainModule = 'Main';

var app = Elm[mainModule].init({
  node: document.getElementById('elm'),
});

var modules = ['Geolocation'];

PortFunnel.subscribe(app, {modules: modules});
```

Your top-level Elm file must have two ports, defined similarly as this:

```elm
port cmdPort : Value -> Cmd msg

port subPort : (Value -> msg) -> Sub msg

subscriptions : Model -> Sub Msg
subscriptions model =
    subPort Process
```

If you need to use different names for the ports, see `index.html` for how to specify that.

You can add additional `PortFunnel` modules by putting their JS files in the `js/PortFunnel` directory, adding their names to the `modules` array, and configuring their Elm code in your application source file. See [github.com/billstclair/elm-port-funnel/example](https://github.com/billstclair/elm-port-funnel/tree/master/example) for more information.
