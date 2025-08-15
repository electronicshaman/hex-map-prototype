A hex-based overland map sounds like a great fit for your Australian gold rush roguelike! The spatial relationships and exploration possibilities of hex grids can definitely create more engaging travel mechanics than pure node-based systems.

Here's how I'd approach prototyping this in Godot 4.4:

## Core Hex System Architecture

Start with these fundamental components:

**HexGrid Manager** - A main controller that handles:
- Converting between world coordinates and hex coordinates
- Storing hex data (terrain, encounters, discoveries)
- Managing player movement and pathfinding

**Individual Hex Tiles** - Each hex should know:
- Its hex coordinates (q, r in axial coordinate system)
- Terrain type (goldfield, bush, creek, town, etc.)
- Whether it's been explored/visited
- Any special encounters or points of interest

## Godot Implementation Strategy

I'd recommend using Godot's tilemap system as a foundation, but with custom hex logic:

1. **Create a custom HexTile resource** that extends Resource to store hex data
2. **Use a TileMap node** with a hexagonal tile source for visual representation
3. **Build a separate logical grid** (2D array or dictionary) that maps hex coordinates to your HexTile resources

## Adapting Your Current System

Since you already have graph grammar rules for encounters, you could:
- Keep your encounter generation logic largely intact
- Instead of generating connected nodes, generate encounters for specific hex coordinates
- Use hex neighbors (6 adjacent hexes) as your "connections" for encounter flow
- Apply your grammar rules based on hex distance, terrain types, or exploration patterns

## Prototype Focus Areas

For your initial prototype, I'd tackle these in order:
1. Basic hex grid display and coordinate conversion
2. Player movement between adjacent hexes
3. Simple terrain types and visual feedback
4. Basic encounter placement
5. Fog of war/exploration mechanics

Would you like me to dive deeper into any of these areas, or would you prefer to see some specific Godot code examples for getting started with the hex coordinate system?