# Tyrion

[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/rwaldron/tyrion?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Tyrion is an agent/device pair for controlling an [Electric Imp](https://electricimp.com/) from a remote machine with [Johnny-Five](https://github.com/rwaldron/johnny-five) and [Imp-IO](https://github.com/rwaldron/imp-io). 

## Getting Started

1. Follow Electric Imp's [Getting Started](https://electricimp.com/docs/gettingstarted/) instructions to set up a wifi connection to your Electric Imp device. 
2. Once your Imp is setup, open the [IDE](https://ide.electricimp.com/ide) (familiarize yourself [here](https://electricimp.com/docs/gettingstarted/ide/)) and click **Create New Model**, give it a name and assign it to your device.
3. Paste the contents of `agent.nut` into the **Agent** pane and `device.nut` into the **Device** pane: 
![Imp Setup](https://raw.githubusercontent.com/rwaldron/tyrion/master/imp-setup.png)
4. Expand the **Active Model** in the column on the left by click on the rightward arrow. The model will appear below, click on the model.
4. Click **Build and Run** to finish preparing your Electric Imp.


## License
See LICENSE file.


