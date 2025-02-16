# ComputerCraft Turtle Tunnel Digging Script

This project contains a Lua script designed to automate the process of digging tunnels using a ComputerCraft Turtle in Minecraft. The script allows the Turtle to dig tunnels of specified dimensions, place torches at regular intervals, and manage its inventory efficiently.

## Features

- **Automated Tunnel Digging**: The Turtle can dig tunnels of specified length and height.
- **Bridge Building**: The Turtle can build bridges if it encounters gaps.
- **Torch Placement**: The Turtle places torches at regular intervals to keep the tunnels lit.
- **Inventory Management**: The Turtle manages its inventory, stacking items and transferring excess items to chests.
- **Valuable Block Detection**: The Turtle can detect and avoid valuable blocks, allowing the player to mine them manually.

## Requirements

- Minecraft with the ComputerCraft mod installed.
- A Turtle with sufficient fuel and the necessary items in its inventory.

## Setup

1. **Install ComputerCraft**: Ensure you have the ComputerCraft mod installed in your Minecraft setup.
2. **Prepare the Turtle**: Place the following items in the specified slots of the Turtle's inventory:
   - Slot 1: Bridge building blocks (e.g., cobblestone)
   - Slot 2: Torches
   - Slot 3: Chests
   - Slot 16: Leave empty (working register)
3. **Load the Script**: Either copy the contents of the `mine.lua` file into a ComputerCraft Turtle or download the file directly to the Turtle using the built-in `wget` command (e.g., `wget https://raw.githubusercontent.com/frederik-hoeft/minecraft-turtle/refs/heads/main/mine.lua mine.lua`).

## Usage

1. **Run the Script**: Execute the script on the Turtle by typing `tunnel` in the Turtle's terminal.
2. **Provide Input**: The script will prompt you to enter the following details:
   - Number of tunnels to dig: In each iteration, the Turtle will move forward 3 blocks and dig offshooting tunnels to the left and right. Each iteration is considered a tunnel.
   - Length of each tunnel offshoot, starting from the main tunnel
   - Height of each tunnel
   - Torch placement interval (every nth tunnel): usually best set to just 1 (every tunnel)
   - Whether to place torches at the end of each tunnel (y/n): good for long offshoots
   - IDs of valuable blocks to avoid (one per line, empty line to finish): e.g., `minecraft:diamond_ore`, allowing you to mine them manually with a fortune pickaxe.
3. **Do something else**: The Turtle will start digging the tunnels based on the provided input. It will manage its inventory, place torches, and avoid valuable blocks as specified.

> [!WARNING]
> The turtle will not automatically refuel itself. Make sure to keep an eye on its fuel level and refuel it as needed.

> [!WARNING]
> Ensure that the chunks the Turtle is operating in are loaded. If you move too far away from the Turtle, it will probably stop working.

## Example

```sh
Provide the following items in the following slots (1-indexed):
Bridge item: slot 1
Torch item: slot 2
Chest item: slot 3
Leave slot 16 empty at all times (working register)
Enter the number of tunnels to dig:
15
Enter the length of each tunnel:
10
Enter tunnel height:
6
Torch placement every nth tunnel (n):
1
Torches at end of tunnel? (y/n)
y
Perhaps there are valuable blocks you want to mine yourself (e.g., with a fortune pickaxe)?
Enter IDs of blocks to navigate around, one per line, empty line to finish:
minecraft:diamond_ore
minecraft:deepslate_diamond_ore

```

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests to improve the script.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

---

_This documentation file was generated from source code using GitHub Copilot. Although the content has been reviewed, it may still contain errors or inaccuracies._