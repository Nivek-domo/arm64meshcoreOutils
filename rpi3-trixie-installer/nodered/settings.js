const settings = {
    httpNodeRoot: '/',
    userDir: '/home/pi/.node-red/',
    functionGlobalContext: {
        // Add your custom global variables here
    },
    editorTheme: {
        page: {
            title: "Node-RED on Raspberry Pi",
            favicon: "http://example.com/favicon.ico",
            css: "/path/to/custom.css",
            scripts: ["/path/to/custom.js"],
            header: "Welcome to Node-RED",
            footer: "Footer text here"
        },
        header: {
            title: "Node-RED",
            image: "http://example.com/logo.png",
            url: "http://example.com"
        },
        menu: {
            "menu-item": {
                label: "My Menu Item",
                url: "http://example.com"
            }
        }
    },
    logging: {
        console: {
            level: "info",
            metrics: false,
            audit: false
        }
    },
    editor: {
        theme: {
            palette: {
                primaryColor: "#ff0000",
                secondaryColor: "#00ff00"
            }
        }
    }
};

module.exports = settings;