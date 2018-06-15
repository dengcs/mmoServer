(function()
{
    var Event  = Laya.Event;
    var Socket = Laya.Socket;
    var Byte   = Laya.Byte;
    var Loader = Laya.Loader;
    var Browser = Laya.Browser;
    var Handler = Laya.Handler;

    var ProtoBuf = Browser.window.protobuf;

    var socket;
    var socket2;

    var account_login;
    var create_player;
    var MsgMessage;
    var ErrorMessage;
    var HeaderMessage;

    (function()
    {
        Laya.init(550, 400);

        ProtoBuf.load(["proto/base.proto","proto/account.proto","proto/auth.proto"], onAssetsLoaded);
    })();

    function onAssetsLoaded(err, root)
    {
        if (err)
            throw err;

        // Obtain a message type
        account_login = root.lookup("game.account_login");
        create_player = root.lookup("game.create_player");
        ErrorMessage = root.lookup("game.NetError");
        HeaderMessage = root.lookup("game.NetHeader");
        MsgMessage = root.lookup("game.NetMessage");        

        //connect();
        connect2();
    }

    function connect()
    {
        socket = new Socket();
        //socket.connect("echo.websocket.org", 80);
        socket.connectByUrl("ws://192.168.8.200:50001");

        socket.on(Event.OPEN, this, onSocketOpen);
        socket.on(Event.CLOSE, this, onSocketClose);
        socket.on(Event.MESSAGE, this, onMessageReveived);
        socket.on(Event.ERROR, this, onConnectError);
    }

    function onSocketOpen()
    {
        console.log("Connected");

        // Create a new message
        var accountMessage = account_login.create(
        {
            account: "dengcs",
            passwd : "12345678"
        });     

        // Encode a message to an Uint8Array (browser) or Buffer (node)
        var accountBuffer = account_login.encode(accountMessage).finish();

        var headerMessage = 
        {
            uid: 1001,
            proto: "account_login"
        };  

        var errorMessage = 
        {
            code: 0
        };  

        var msgMessage = MsgMessage.fromObject(
        {
            header: headerMessage,
            error: errorMessage,
            payload: accountBuffer
        });

        var sendBuffer = MsgMessage.encode(msgMessage).finish();
        socket.send(sendBuffer);
    }

    function onSocketClose()
    {
        console.log("Socket closed");
    }

    function onMessageReveived(message)
    {
        console.log("Message from server:");

        if (typeof message == "string")
        {
            console.log(message);
        }
        else if (message instanceof ArrayBuffer)
        {
            var ddbuf = new Uint8Array(message);
            var debuf = MsgMessage.decode(ddbuf);
            console.log(debuf);
            console.log(debuf.header);
            console.log(debuf.error);
            console.log(debuf.payload);
        }
        
        socket.input.clear();
    }

    function connect2()
    {
        socket2 = new Socket();
        //socket.connect("echo.websocket.org", 80);
        socket2.connectByUrl("ws://192.168.8.200:51001");
        
        socket2.on(Event.OPEN, this, onSocketOpen2);
        socket2.on(Event.CLOSE, this, onSocketClose2);
        socket2.on(Event.MESSAGE, this, onMessageReveived2);
        socket2.on(Event.ERROR, this, onConnectError2);
    }

    function onConnectError(e)
    {
        console.log("error");
    }

    function onSocketOpen2()
    {
        console.log("Connected2");

        // Create a new message
        var createMessage = create_player.create(
        {
        });     

        // Encode a message to an Uint8Array (browser) or Buffer (node)
        var createBuffer = create_player.encode(createMessage).finish();

        var headerMessage = 
        {
            uid: 1001,
            proto: "create_player"
        };  

        var errorMessage = 
        {
            code: 0
        };  

        var msgMessage = MsgMessage.fromObject(
        {
            header: headerMessage,
            error: errorMessage,
            payload: createBuffer
        });

        var sendBuffer = MsgMessage.encode(msgMessage).finish();
        socket2.send(sendBuffer);
    }

    function onSocketClose2()
    {
        console.log("Socket closed2");
    }

    function onMessageReveived2(message)
    {
        console.log("Message from server2:");

        if (typeof message == "string")
        {
            console.log(message);
        }
        else if (message instanceof ArrayBuffer)
        {
            var ddbuf = new Uint8Array(message);
            var debuf = MsgMessage.decode(ddbuf);
            console.log(debuf);
            console.log(debuf.header);
            console.log(debuf.error);
            console.log(debuf.payload);
        }
        
        socket2.input.clear();
    }

    function onConnectError2(e)
    {
        console.log("error2");
    }
})();