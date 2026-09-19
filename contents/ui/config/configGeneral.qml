import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QtControls
import org.kde.kirigami 2.20 as Kirigami

Kirigami.FormLayout {
    property string title: "General"
    property string cfg_printersJsonDefault: ""
    property string cfg_printersJson: '[{"name":"Example Printer","ip":"192.168.0.10"},]'
    property var editorPrinters: []
    property bool syncingConfig: false

    function parsePrinters(value) {
        try {
            var parsed = JSON.parse(value || "[]");
            if (!Array.isArray(parsed)) return [];
            return parsed.filter(function(printer) {
                return printer && printer.name && printer.ip;
            }).map(function(printer) {
                return { name: String(printer.name), ip: String(printer.ip) };
            });
        } catch (error) {
            return [];
        }
    }

    function syncConfig() {
        syncingConfig = true;
        cfg_printersJson = JSON.stringify(editorPrinters);
        syncingConfig = false;
    }

    function updatePrinter(index, field, value) {
        editorPrinters[index][field] = value;
        syncConfig();
    }

    function removePrinter(index) {
        var updated = editorPrinters.slice();
        updated.splice(index, 1);
        editorPrinters = updated;
        syncConfig();
    }

    function addPrinter() {
        editorPrinters = editorPrinters.concat([{ name: "", ip: "" }]);
        syncConfig();
    }

    Component.onCompleted: editorPrinters = parsePrinters(cfg_printersJson)

    onCfg_printersJsonChanged: {
        if (!syncingConfig && cfg_printersJson !== JSON.stringify(editorPrinters)) {
            editorPrinters = parsePrinters(cfg_printersJson)
        }
    }

    ColumnLayout {
        width: 440
        Layout.fillWidth: false
        Layout.minimumWidth: 440
        Layout.preferredWidth: 440
        Layout.maximumWidth: 440
        Layout.alignment: Qt.AlignCenter | Qt.AlignVCenter

        QtControls.Label {
            width: 440
            text: "Printers"
            font.bold: true
            Layout.fillWidth: false
            Layout.minimumWidth: 440
            Layout.preferredWidth: 440
            Layout.maximumWidth: 440
        }

        Repeater {
            model: editorPrinters

            delegate: RowLayout {
                width: 440
                Layout.fillWidth: false
                Layout.minimumWidth: 440
                Layout.preferredWidth: 440
                Layout.maximumWidth: 440
                spacing: 8

                QtControls.TextField {
                    Layout.preferredWidth: 180
                    Layout.minimumWidth: 180
                    Layout.maximumWidth: 180
                    placeholderText: "Name"
                    text: modelData.name
                    selectByMouse: true
                    onTextChanged: {
                        if (text !== modelData.name) updatePrinter(index, "name", text)
                    }
                }

                QtControls.TextField {
                    width: 130
                    Layout.preferredWidth: 130
                    Layout.minimumWidth: 130
                    Layout.maximumWidth: 130
                    placeholderText: "IP address"
                    text: modelData.ip
                    selectByMouse: true
                    onTextChanged: {
                        if (text !== modelData.ip) updatePrinter(index, "ip", text)
                    }
                }

                QtControls.Button {
                    width: 82
                    Layout.minimumWidth: 82
                    Layout.preferredWidth: 82
                    Layout.maximumWidth: 82
                    text: "Remove"
                    onClicked: removePrinter(index)
                }
            }
        }

        QtControls.Button {
            width: 90
            Layout.minimumWidth: 90
            Layout.preferredWidth: 90
            Layout.maximumWidth: 90
            text: "Add printer"
            onClicked: addPrinter()
        }
    }
}