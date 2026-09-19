import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents

PlasmoidItem {
    id: root

    // Removes the panel/desktop background frame completely
    Plasmoid.backgroundHints: "NoBackground"

    // Default sizing on the desktop
    width: 650
    height: 280

    property var printers: []

    function configuredPrinters() {
        var configured = [];
        try {
            var parsed = JSON.parse(plasmoid.configuration.printersJson || "[]");
            if (!Array.isArray(parsed)) return configured;

            for (var i = 0; i < parsed.length; i++) {
                var printer = parsed[i];
                if (printer && printer.name && printer.ip) {
                    configured.push({
                        name: String(printer.name),
                        ip: String(printer.ip),
                        printPercent: 0,
                        message: "Fetching...",
                        state: "standby",
                        finishTime: 0
                    });
                }
            }
        } catch (error) {
            console.warn("Invalid printer configuration:", error);
        }
        return configured;
    }

    function loadConfiguredPrinters() {
        root.printers = root.configuredPrinters();
    }
    function fetchPrinterState() {
        var updatedPrinters = root.printers.slice();
        var completedRequests = 0;
        var hasVisibleChanges = false;
        for (let i=0; i<updatedPrinters.length; i++) {
            let printerIndex = i;
            let xhr = new XMLHttpRequest();

            xhr.open("GET", `http://${updatedPrinters[printerIndex].ip}:7125/printer/objects/query?display_status&print_stats&webhooks`, true);

            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        try {
                            var json = JSON.parse(xhr.responseText).result.status;
                            var printPercent = Math.floor(json.display_status.progress * 100);
                            var printerState = json.print_stats.state;
                            var printerMessage = json.display_status.message || json.print_stats.message || json.print_stats.state;
                            hasVisibleChanges = hasVisibleChanges
                                || updatedPrinters[printerIndex].printPercent !== printPercent
                                || updatedPrinters[printerIndex].state !== printerState
                                || updatedPrinters[printerIndex].message !== printerMessage;
                            updatedPrinters[printerIndex].printPercent = printPercent;
                            updatedPrinters[printerIndex].state = printerState;
                            updatedPrinters[printerIndex].message = printerMessage;
                            var print_duration = json.print_stats.print_duration / json.display_status.progress;
                            updatedPrinters[printerIndex].finishTime = Date.now() + (print_duration - json.print_stats.total_duration) * 1000;
                        } catch (e) {
                            hasVisibleChanges = hasVisibleChanges || updatedPrinters[printerIndex].message !== "JSON parse error";
                            updatedPrinters[printerIndex].message = "JSON parse error";
                        }
                    } else {
                        var httpMessage = "HTTP Error: " + xhr.status;
                        hasVisibleChanges = hasVisibleChanges || updatedPrinters[printerIndex].message !== httpMessage;
                        updatedPrinters[printerIndex].message = httpMessage;
                    }

                    completedRequests++;
                    if (completedRequests === updatedPrinters.length && hasVisibleChanges) {
                        root.printers = updatedPrinters.slice();
                    }
                }
            };

            xhr.send();
        }
    }

    function stateColor(state) {
        switch (state) {
        case "complete":
        case "completed":
            return "#36b37e";
        case "printing":
            return "#4c9aff";
        case "error":
            return "#e5484d";
        case "paused":
            return "#f2c94c";
        default:
            return "#8b949e";
        }
    }

    function formatRemaining(printer) {
        if (printer.state != "printing") return "/";
        if (!Number.isFinite(printer.finishTime)) return "...";
        var remaining = Math.max(0, Math.floor((printer.finishTime - Date.now()) / 1000));
        var hours = Math.floor(remaining / 3600);
        var minutes = Math.floor((remaining % 3600) / 60);
        return hours > 0 ? hours + "h " + minutes + "m" : minutes + "m";
    }

    function formatFinishTime(printer) {
        if (printer.state != "printing") return "/";
        if (!Number.isFinite(printer.finishTime)) return "...";
        return Qt.formatDateTime(new Date(printer.finishTime), "HH:mm");
    }

    // Trigger initial request when widget finishes loading
    Component.onCompleted: {
        loadConfiguredPrinters();
        fetchPrinterState();
    }

    // Refresh every 10 seconds
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.fetchPrinterState()
    }

    Connections {
        target: plasmoid.configuration
        function onPrintersJsonChanged() {
            root.loadConfiguredPrinters();
            root.fetchPrinterState();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rows: 2
            columnSpacing: 30
            rowSpacing: 12

            Repeater {
                model: root.printers

                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 300
                    spacing: 4

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: modelData.name
                        horizontalAlignment: Text.AlignLeft
                        font.bold: true
                        font.pixelSize: 14
                        color: "#f0f6fc"
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12

                        ColumnLayout {
                            Layout.preferredWidth: 96
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 4

                            Item {
                                id: progressContainer
                                Layout.preferredWidth: 82
                                Layout.preferredHeight: 82

                                Canvas {
                                    id: progressCanvas
                                    anchors.fill: parent
                                    property real progress: Math.max(0, Math.min(100, Number(modelData.printPercent) || 0))
                                    property color progressColor: root.stateColor(modelData.state)

                                    onProgressChanged: requestPaint()
                                    onProgressColorChanged: requestPaint()

                                    onPaint: {
                                        var context = getContext("2d");
                                        var center = width / 2;
                                        var radius = Math.min(width, height) / 2 - 7;
                                        var start = -Math.PI / 2;

                                        context.reset();
                                        context.lineWidth = 8;
                                        context.lineCap = "round";
                                        context.beginPath();
                                        context.arc(center, center, radius, 0, Math.PI * 2);
                                        context.strokeStyle = "#30363d";
                                        context.stroke();

                                        context.beginPath();
                                        context.arc(center, center, radius, start, start + Math.PI * 2 * progress / 100);
                                        context.strokeStyle = progressColor;
                                        context.stroke();
                                    }
                                }

                                PlasmaComponents.Label {
                                    anchors.centerIn: parent
                                    text: Math.round(progressCanvas.progress) + "%"
                                    font.bold: true
                                    font.pixelSize: 18
                                    color: "#f0f6fc"
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            spacing: 6

                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: "ETA: " + root.formatRemaining(modelData) + " | " + root.formatFinishTime(modelData)
                                horizontalAlignment: Text.AlignLeft
                                font.pixelSize: 13
                                color: "#b1bac4"
                            }

                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: modelData.message
                                horizontalAlignment: Text.AlignLeft
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                color: "#b1bac4"
                            }
                        }
                    }
                }
            }
        }
    }
}

