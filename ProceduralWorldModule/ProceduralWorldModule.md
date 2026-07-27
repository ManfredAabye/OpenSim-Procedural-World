Sie haben einen hervorragenden Entwurf für eine prozedurale Welterzeugungs-Engine für OpenSimulator vorgelegt. 
Ich werde das Grundgerüst implementieren, das auf den vorhandenen Modulen aufbaut und Ihre Architektur umsetzt.

## Phase 1 – Grundgerüst Implementierung

### 1. WorldGeneratorModule.cs - Hauptmodul

```csharp
using System;
using System.Collections.Generic;
using System.Reflection;
using log4net;
using Nini.Config;
using OpenSim.Framework;
using OpenSim.Region.Framework.Interfaces;
using OpenSim.Region.Framework.Scenes;
using OpenSim.Region.OptionalModules.WorldGenerator.Configuration;
using OpenSim.Region.OptionalModules.WorldGenerator.Terrain;
using OpenSim.Region.OptionalModules.WorldGenerator.Biomes;
using OpenSim.Region.OptionalModules.WorldGenerator.Vegetation;

namespace OpenSim.Region.OptionalModules.WorldGenerator
{
    public class WorldGeneratorModule : ISharedRegionModule
    {
        private static readonly ILog m_log = LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
        
        private bool m_enabled = false;
        private WorldConfig m_config;
        private WorldManager m_worldManager;
        private TerrainGenerator m_terrainGenerator;
        private BiomeGenerator m_biomeGenerator;
        private ForestGenerator m_forestGenerator;

        public string Name => "WorldGeneratorModule";
        public Type ReplaceableInterface => null;

        public void Initialise(IConfigSource source)
        {
            IConfig config = source.Configs["WorldGenerator"];
            if (config == null)
            {
                m_log.Info("[WORLD GENERATOR]: Module not configured, disabled.");
                return;
            }

            m_enabled = config.GetBoolean("Enabled", false);
            if (!m_enabled)
            {
                m_log.Info("[WORLD GENERATOR]: Module disabled.");
                return;
            }

            m_log.Info("[WORLD GENERATOR]: Initializing...");
            m_config = new WorldConfig(config);
            
            // Initialisiere Komponenten
            m_worldManager = new WorldManager(m_config);
            m_terrainGenerator = new TerrainGenerator(m_config);
            m_biomeGenerator = new BiomeGenerator(m_config);
            m_forestGenerator = new ForestGenerator(m_config);
        }

        public void PostInitialise()
        {
            if (!m_enabled) return;
            m_log.Info("[WORLD GENERATOR]: Post-initialization complete.");
        }

        public void Close()
        {
            if (!m_enabled) return;
            m_log.Info("[WORLD GENERATOR]: Shutting down...");
        }

        public void AddRegion(Scene scene)
        {
            if (!m_enabled) return;
            
            try
            {
                m_log.Info($"[WORLD GENERATOR]: Generating world for region {scene.RegionInfo.RegionName}...");
                
                // 1. Terrain generieren
                var heightmap = m_terrainGenerator.GenerateHeightmap(scene.RegionInfo.RegionSizeX, scene.RegionInfo.RegionSizeY);
                
                // 2. Biome-Karte generieren
                var biomeMap = m_biomeGenerator.GenerateBiomeMap(scene.RegionInfo.RegionSizeX, scene.RegionInfo.RegionSizeY, heightmap);
                
                // 3. Vegetation generieren
                m_forestGenerator.GenerateVegetation(scene, heightmap, biomeMap);
                
                // 4. Terrain texturieren
                TerrainPainter.PaintTerrain(scene, heightmap, biomeMap);
                
                m_log.Info($"[WORLD GENERATOR]: World generation completed for {scene.RegionInfo.RegionName}");
            }
            catch (Exception ex)
            {
                m_log.Error($"[WORLD GENERATOR]: Error generating world: {ex.Message}");
            }
        }

        public void RemoveRegion(Scene scene)
        {
            if (!m_enabled) return;
            m_log.Info($"[WORLD GENERATOR]: Removing region {scene.RegionInfo.RegionName}");
        }

        public void RegionLoaded(Scene scene)
        {
            if (!m_enabled) return;
            // Zusätzliche Initialisierung nach Laden der Region
        }
    }
}
```

### 2. WorldConfig.cs - Konfiguration

```csharp
using System;
using Nini.Config;

namespace OpenSim.Region.OptionalModules.WorldGenerator.Configuration
{
    public class WorldConfig
    {
        // Terrain Parameter
        public int Seed { get; private set; }
        public float HeightScale { get; private set; }
        public float Frequency { get; private set; }
        public int Octaves { get; private set; }
        public float Lacunarity { get; private set; }
        public float Gain { get; private set; }
        
        // Vegetation Parameter
        public int MaxTrees { get; private set; }
        public int MaxBushes { get; private set; }
        public float ForestCoverage { get; private set; }
        
        // Wasser Parameter
        public float WaterLevel { get; private set; }
        public int RiverCount { get; private set; }
        public int LakeCount { get; private set; }
        
        // Biome Parameter
        public float BiomeScale { get; private set; }
        
        // Siedlungen
        public int MaxSettlements { get; private set; }
        public float SettlementDensity { get; private set; }

        public WorldConfig(IConfig config)
        {
            // Lade Standardwerte oder aus Konfiguration
            Seed = config.GetInt("Seed", DateTime.Now.Millisecond);
            HeightScale = config.GetFloat("HeightScale", 40.0f);
            Frequency = config.GetFloat("Frequency", 0.02f);
            Octaves = config.GetInt("Octaves", 6);
            Lacunarity = config.GetFloat("Lacunarity", 2.0f);
            Gain = config.GetFloat("Gain", 0.5f);
            
            MaxTrees = config.GetInt("MaxTrees", 5000);
            MaxBushes = config.GetInt("MaxBushes", 3000);
            ForestCoverage = config.GetFloat("ForestCoverage", 0.3f);
            
            WaterLevel = config.GetFloat("WaterLevel", 20.0f);
            RiverCount = config.GetInt("RiverCount", 3);
            LakeCount = config.GetInt("LakeCount", 2);
            
            BiomeScale = config.GetFloat("BiomeScale", 0.01f);
            
            MaxSettlements = config.GetInt("MaxSettlements", 5);
            SettlementDensity = config.GetFloat("SettlementDensity", 0.1f);
        }
    }
}
```

### 3. WorldManager.cs - Weltmanager

```csharp
using System.Collections.Generic;
using OpenSim.Region.OptionalModules.WorldGenerator.Configuration;

namespace OpenSim.Region.OptionalModules.WorldGenerator
{
    public class WorldManager
    {
        private WorldConfig m_config;
        private Dictionary<string, object> m_worldData;
        
        public WorldManager(WorldConfig config)
        {
            m_config = config;
            m_worldData = new Dictionary<string, object>();
        }
        
        public void StoreWorldData(string key, object data)
        {
            if (m_worldData.ContainsKey(key))
                m_worldData[key] = data;
            else
                m_worldData.Add(key, data);
        }
        
        public T GetWorldData<T>(string key)
        {
            if (m_worldData.TryGetValue(key, out object data) && data is T typedData)
                return typedData;
            
            return default(T);
        }
        
        public WorldConfig Config => m_config;
    }
}
```

### 4. Terrain/TerrainGenerator.cs

```csharp
using System;
using OpenSim.Region.OptionalModules.WorldGenerator.Configuration;
using OpenSim.Region.OptionalModules.WorldGenerator.Noise;

namespace OpenSim.Region.OptionalModules.WorldGenerator.Terrain
{
    public class TerrainGenerator
    {
        private WorldConfig m_config;
        private FBMNoise m_fbmNoise;
        
        public TerrainGenerator(WorldConfig config)
        {
            m_config = config;
            m_fbmNoise = new FBMNoise(config.Seed, config.Octaves, config.Lacunarity, config.Gain);
        }
        
        public HeightMap GenerateHeightmap(int width, int height)
        {
            var heightmap = new HeightMap(width, height);
            
            for (int x = 0; x < width; x++)
            {
                for (int y = 0; y < height; y++)
                {
                    // Skaliere Koordinaten für Rauschen
                    float nx = x * m_config.Frequency;
                    float ny = y * m_config.Frequency;
                    
                    // Generiere Höhe mit FBM
                    float height = m_fbmNoise.Generate(nx, ny) * m_config.HeightScale;
                    
                    // Wasser-Level anwenden
                    if (height < m_config.WaterLevel)
                        height = m_config.WaterLevel - 0.5f; // Leicht unter Wasser
                    
                    heightmap.SetHeight(x, y, height);
                }
            }
            
            // Optional: Erosion anwenden
            ApplyErosion(heightmap);
            
            // Flüsse generieren
            GenerateRivers(heightmap);
            
            // Seen generieren
            GenerateLakes(heightmap);
            
            return heightmap;
        }
        
        private void ApplyErosion(HeightMap heightmap)
        {
            // Einfache thermische Erosion
            float erosionStrength = 0.1f;
            int iterations = 3;
            
            for (int iter = 0; iter < iterations; iter++)
            {
                var newHeightmap = new HeightMap(heightmap.Width, heightmap.Height);
                
                for (int x = 1; x < heightmap.Width - 1; x++)
                {
                    for (int y = 1; y < heightmap.Height - 1; y++)
                    {
                        float current = heightmap.GetHeight(x, y);
                        float totalDiff = 0;
                        int count = 0;
                        
                        // Nachbarhöhen sammeln
                        for (int dx = -1; dx <= 1; dx++)
                        {
                            for (int dy = -1; dy <= 1; dy++)
                            {
                                if (dx == 0 && dy == 0) continue;
                                totalDiff += heightmap.GetHeight(x + dx, y + dy) - current;
                                count++;
                            }
                        }
                        
                        float avgDiff = totalDiff / count;
                        newHeightmap.SetHeight(x, y, current + avgDiff * erosionStrength);
                    }
                }
                
                heightmap = newHeightmap;
            }
        }
        
        private void GenerateRivers(HeightMap heightmap)
        {
            // Flussgenerierungs-Logik (vereinfacht)
            var riverGenerator = new RiverGenerator(m_config.RiverCount);
            riverGenerator.GenerateRivers(heightmap);
        }
        
        private void GenerateLakes(HeightMap heightmap)
        {
            // Seengenerierung (vereinfacht)
            var lakeGenerator = new LakeGenerator(m_config.LakeCount);
            lakeGenerator.GenerateLakes(heightmap);
        }
    }
}
```

### 5. Terrain/HeightMap.cs

```csharp
using System;

namespace OpenSim.Region.OptionalModules.WorldGenerator.Terrain
{
    public class HeightMap
    {
        private float[,] m_heightmap;
        public int Width { get; private set; }
        public int Height { get; private set; }
        
        public HeightMap(int width, int height)
        {
            Width = width;
            Height = height;
            m_heightmap = new float[width, height];
        }
        
        public float GetHeight(int x, int y)
        {
            if (x < 0 || x >= Width || y < 0 || y >= Height)
                return 0;
            
            return m_heightmap[x, y];
        }
        
        public void SetHeight(int x, int y, float height)
        {
            if (x < 0 || x >= Width || y < 0 || y >= Height)
                return;
            
            m_heightmap[x, y] = height;
        }
        
        public float GetNormalizedHeight(int x, int y)
        {
            return GetHeight(x, y) / 100.0f; // Normalisierung
        }
        
        public float GetSlope(int x, int y)
        {
            if (x <= 0 || x >= Width - 1 || y <= 0 || y >= Height - 1)
                return 0;
            
            float hx = GetHeight(x + 1, y) - GetHeight(x - 1, y);
            float hy = GetHeight(x, y + 1) - GetHeight(x, y - 1);
            
            return (float)Math.Sqrt(hx * hx + hy * hy);
        }
    }
}
```

### 6. Noise/PerlinNoise.cs

```csharp
using System;

namespace OpenSim.Region.OptionalModules.WorldGenerator.Noise
{
    public class PerlinNoise
    {
        private int[] p;
        private int seed;
        
        public PerlinNoise(int seed)
        {
            this.seed = seed;
            InitPermutationTable();
        }
        
        private void InitPermutationTable()
        {
            p = new int[512];
            int[] permutation = new int[256];
            
            // Fülle mit Werten 0-255
            for (int i = 0; i < 256; i++)
                permutation[i] = i;
            
            // Mische mit Seed
            Random rand = new Random(seed);
            for (int i = 255; i > 0; i--)
            {
                int j = rand.Next(i + 1);
                int temp = permutation[i];
                permutation[i] = permutation[j];
                permutation[j] = temp;
            }
            
            // Verdoppele für einfacheren Zugriff
            for (int i = 0; i < 512; i++)
                p[i] = permutation[i & 255];
        }
        
        public float Generate(float x, float y)
        {
            int X = (int)Math.Floor(x) & 255;
            int Y = (int)Math.Floor(y) & 255;
            
            float xf = x - (float)Math.Floor(x);
            float yf = y - (float)Math.Floor(y);
            
            float u = Fade(xf);
            float v = Fade(yf);
            
            int aa = p[p[X] + Y];
            int ab = p[p[X] + Y + 1];
            int ba = p[p[X + 1] + Y];
            int bb = p[p[X + 1] + Y + 1];
            
            return Lerp(v, Lerp(u, Grad(aa, xf, yf), Grad(ba, xf - 1, yf)),
                          Lerp(u, Grad(ab, xf, yf - 1), Grad(bb, xf - 1, yf - 1)));
        }
        
        private float Fade(float t)
        {
            return t * t * t * (t * (t * 6 - 15) + 10);
        }
        
        private float Lerp(float t, float a, float b)
        {
            return a + t * (b - a);
        }
        
        private float Grad(int hash, float x, float y)
        {
            int h = hash & 3;
            float u = h < 2 ? x : y;
            float v = h < 2 ? y : x;
            return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v);
        }
    }
}
```

### 7. Noise/FBMNoise.cs

```csharp
using System;

namespace OpenSim.Region.OptionalModules.WorldGenerator.Noise
{
    public class FBMNoise
    {
        private PerlinNoise m_perlin;
        private int m_octaves;
        private float m_lacunarity;
        private float m_gain;
        private float m_frequency;
        
        public FBMNoise(int seed, int octaves = 6, float lacunarity = 2.0f, float gain = 0.5f)
        {
            m_perlin = new PerlinNoise(seed);
            m_octaves = octaves;
            m_lacunarity = lacunarity;
            m_gain = gain;
            m_frequency = 1.0f;
        }
        
        public float Generate(float x, float y, float frequency = 1.0f)
        {
            float value = 0;
            float amplitude = 1.0f;
            float maxAmplitude = 0;
            float freq = frequency;
            
            for (int i = 0; i < m_octaves; i++)
            {
                value += m_perlin.Generate(x * freq, y * freq) * amplitude;
                maxAmplitude += amplitude;
                amplitude *= m_gain;
                freq *= m_lacunarity;
            }
            
            return value / maxAmplitude; // Normalisieren auf [-1, 1]
        }
        
        public void SetFrequency(float frequency)
        {
            m_frequency = frequency;
        }
    }
}
```

### 8. Biomes/BiomeGenerator.cs

```csharp
using System;
using OpenSim.Region.OptionalModules.WorldGenerator.Configuration;
using OpenSim.Region.OptionalModules.WorldGenerator.Noise;
using OpenSim.Region.OptionalModules.WorldGenerator.Terrain;

namespace OpenSim.Region.OptionalModules.WorldGenerator.Biomes
{
    public class BiomeGenerator
    {
        private WorldConfig m_config;
        private PerlinNoise m_temperatureNoise;
        private PerlinNoise m_humidityNoise;
        
        public BiomeGenerator(WorldConfig config)
        {
            m_config = config;
            m_temperatureNoise = new PerlinNoise(config.Seed + 1);
            m_humidityNoise = new PerlinNoise(config.Seed + 2);
        }
        
        public BiomeMap GenerateBiomeMap(int width, int height, HeightMap heightmap)
        {
            var biomeMap = new BiomeMap(width, height);
            
            for (int x = 0; x < width; x++)
            {
                for (int y = 0; y < height; y++)
                {
                    float nx = x * m_config.BiomeScale;
                    float ny = y * m_config.BiomeScale;
                    
                    // Temperatur (abhängig von Höhe und Breitengrad)
                    float temperature = CalculateTemperature(heightmap.GetHeight(x, y), y, height);
                    
                    // Feuchtigkeit (abhängig von Niederschlag und Höhe)
                    float humidity = CalculateHumidity(heightmap.GetHeight(x, y), nx, ny);
                    
                    // Bestimme Biome basierend auf Temperatur und Feuchtigkeit
                    BiomeType biome = DetermineBiome(temperature, humidity, heightmap.GetHeight(x, y));
                    
                    biomeMap.SetBiome(x, y, biome);
                    
                    // Speichere zusätzliche Daten
                    biomeMap.SetTemperature(x, y, temperature);
                    biomeMap.SetHumidity(x, y, humidity);
                }
            }
            
            return biomeMap;
        }
        
        private float CalculateTemperature(float height, int y, int heightMapHeight)
        {
            // Temperatur sinkt mit Höhe und steigt zum Äquator
            float latitudeFactor = 1.0f - Math.Abs((float)y / heightMapHeight - 0.5f) * 2.0f;
            float heightFactor = 1.0f - height / 100.0f;
            
            return Math.Max(0, Math.Min(1, (latitudeFactor * 0.6f + heightFactor * 0.4f)));
        }
        
        private float CalculateHumidity(float height, float nx, float ny)
        {
            // Feuchtigkeit durch Rauschen und Höhe beeinflusst
            float noise = m_humidityNoise.Generate(nx, ny) * 0.5f + 0.5f;
            float heightFactor = 1.0f - height / 80.0f;
            
            return Math.Max(0, Math.Min(1, noise * 0.7f + heightFactor * 0.3f));
        }
        
        private BiomeType DetermineBiome(float temperature, float humidity, float height)
        {
            if (height < m_config.WaterLevel)
            {
                if (height < m_config.WaterLevel - 5.0f)
                    return BiomeType.DeepWater;
                return BiomeType.Water;
            }
            
            if (height > 70.0f)
                return BiomeType.Mountain;
            
            if (height > 50.0f)
                return BiomeType.Highland;
            
            // Temperatur- und Feuchtigkeits-Klassifizierung
            if (temperature > 0.7f)
            {
                if (humidity > 0.6f)
                    return BiomeType.TropicalRainforest;
                else if (humidity > 0.3f)
                    return BiomeType.Savanna;
                else
                    return BiomeType.Desert;
            }
            else if (temperature > 0.4f)
            {
                if (humidity > 0.6f)
                    return BiomeType.TemperateForest;
                else if (humidity > 0.3f)
                    return BiomeType.Grassland;
                else
                    return BiomeType.Scrubland;
            }
            else
            {
                if (humidity > 0.6f)
                    return BiomeType.Taiga;
                else if (humidity > 0.3f)
                    return BiomeType.Tundra;
                else
                    return BiomeType.PolarDesert;
            }
        }
    }
}
```

### 9. Biomes/BiomeType.cs

```csharp
namespace OpenSim.Region.OptionalModules.WorldGenerator.Biomes
{
    public enum BiomeType
    {
        Water,
        DeepWater,
        Beach,
        Desert,
        Savanna,
        TropicalRainforest,
        Grassland,
        TemperateForest,
        Scrubland,
        Taiga,
        Tundra,
        PolarDesert,
        Mountain,
        Highland,
        Urban,
        Farmland
    }
}
```

### 10. Vegetation/ForestGenerator.cs

```csharp
using System;
using System.Collections.Generic;
using OpenSim.Framework;
using OpenSim.Region.Framework.Scenes;
using OpenSim.Region.OptionalModules.WorldGenerator.Biomes;
using OpenSim.Region.OptionalModules.WorldGenerator.Configuration;
using OpenSim.Region.OptionalModules.WorldGenerator.Terrain;
using OpenSim.Region.OptionalModules.WorldGenerator.Utils;

namespace OpenSim.Region.OptionalModules.WorldGenerator.Vegetation
{
    public class ForestGenerator
    {
        private WorldConfig m_config;
        private Random m_random;
        
        public ForestGenerator(WorldConfig config)
        {
            m_config = config;
            m_random = new Random(config.Seed + 10);
        }
        
        public void GenerateVegetation(Scene scene, HeightMap heightmap, BiomeMap biomeMap)
        {
            int width = heightmap.Width;
            int height = heightmap.Height;
            
            List<TreeCluster> clusters = new List<TreeCluster>();
            
            // Generiere Baum-Cluster basierend auf Biome
            for (int x = 0; x < width; x += 5) // Schrittweite für Effizienz
            {
                for (int y = 0; y < height; y += 5)
                {
                    float heightValue = heightmap.GetHeight(x, y);
                    BiomeType biome = biomeMap.GetBiome(x, y);
                    
                    // Bestimme Vegetationsdichte basierend auf Biome
                    float density = GetVegetationDensity(biome, heightValue);
                    
                    if (density > 0 && m_random.NextDouble() < density)
                    {
                        // Erstelle Baum-Cluster
                        var cluster = new TreeCluster();
                        cluster.Position = new Vector3(x, y, heightValue + 1);
                        cluster.Size = m_random.Next(1, 5);
                        cluster.Species = SelectSpecies(biome, m_random);
                        
                        clusters.Add(cluster);
                    }
                }
            }
            
            // Sortiere und begrenze Anzahl
            clusters.Sort((a, b) => b.Size.CompareTo(a.Size));
            if (clusters.Count > m_config.MaxTrees)
                clusters.RemoveRange(m_config.MaxTrees, clusters.Count - m_config.MaxTrees);
            
            // Platziere Bäume in der Szene
            foreach (var cluster in clusters)
            {
                PlaceTreeCluster(scene, cluster, heightmap);
            }
            
            // Generiere Büsche und Gras
            GenerateUnderGrowth(scene, heightmap, biomeMap);
        }
        
        private float GetVegetationDensity(BiomeType biome, float height)
        {
            switch (biome)
            {
                case BiomeType.TropicalRainforest:
                    return 0.8f;
                case BiomeType.TemperateForest:
                    return 0.6f;
                case BiomeType.Taiga:
                    return 0.4f;
                case BiomeType.Savanna:
                    return 0.3f;
                case BiomeType.Grassland:
                    return 0.2f;
                case BiomeType.Scrubland:
                    return 0.1f;
                case BiomeType.Mountain:
                    return height > 60.0f ? 0.05f : 0.15f;
                case BiomeType.Desert:
                case BiomeType.Tundra:
                case BiomeType.PolarDesert:
                    return 0.01f;
                default:
                    return 0.1f;
            }
        }
        
        private string SelectSpecies(BiomeType biome, Random random)
        {
            // Wähle Baumart basierend auf Biome
            var species = new Dictionary<BiomeType, string[]>
            {
                { BiomeType.TropicalRainforest, new[] { "Palme", "Mahagoni", "Teak" } },
                { BiomeType.TemperateForest, new[] { "Eiche", "Buche", "Ahorn", "Birke" } },
                { BiomeType.Taiga, new[] { "Fichte", "Kiefer", "Tanne" } },
                { BiomeType.Savanna, new[] { "Akazie", "Baobab" } },
                { BiomeType.Grassland, new[] { "Weide", "Birke" } }
            };
            
            if (species.TryGetValue(biome, out string[] availableSpecies))
                return availableSpecies[random.Next(availableSpecies.Length)];
            
            return "Eiche"; // Fallback
        }
        
        private void PlaceTreeCluster(Scene scene, TreeCluster cluster, HeightMap heightmap)
        {
            // Platziere Bäume im Cluster
            for (int i = 0; i < cluster.Size; i++)
            {
                float offsetX = (float)(m_random.NextDouble() * 4 - 2);
                float offsetY = (float)(m_random.NextDouble() * 4 - 2);
                
                int x = (int)(cluster.Position.X + offsetX);
                int y = (int)(cluster.Position.Y + offsetY);
                
                if (x < 0 || x >= heightmap.Width || y < 0 || y >= heightmap.Height)
                    continue;
                
                float height = heightmap.GetHeight(x, y);
                if (height < m_config.WaterLevel)
                    continue;
                
                // Erstelle Baum-Prim
                CreateTreePrim(scene, new Vector3(x, y, height + 0.5f), cluster.Species);
            }
        }
        
        private void CreateTreePrim(Scene scene, Vector3 position, string species)
        {
            try
            {
                // Hier würde die OpenSim-Prim-Erstellung verwendet werden
                // Vereinfachte Darstellung
                UUID ownerID = UUID.Zero;
                string treeName = $"Tree_{species}_{DateTime.Now.Ticks}";
                
                // Prim-Eigenschaften für Baum
                // In einer realen Implementierung würde hier ein richtiger Prim mit Baum-Mesh erstellt
                // oder ein OpenSim-Tree-Objekt verwendet werden
                
                // Beispiel mit Prim:
                var prim = scene.AddNewPrim(
                    ownerID,
                    treeName,
                    new Vector3(position.X, position.Y, position.Z + 0.5f),
                    new Vector3(1, 1, 4),
                    new Quaternion(0, 0, 0, 1),
                    PrimitiveBaseShape.Default
                );
                
                // Baum-spezifische Eigenschaften setzen
                if (prim != null)
                {
                    prim.SetText($"🌳 {species}", new Vector3(0, 1, 0), 0.5f);
                    // Farbe anpassen
                    // prim.UpdatePrimFlags(...);
                }
            }
            catch (Exception ex)
            {
                // Logging
            }
        }
        
        private void GenerateUnderGrowth(Scene scene, HeightMap heightmap, BiomeMap biomeMap)
        {
            // Generiere Büsche und Gras
            // Vereinfachte Implementierung
        }
    }
}
```

## Verwendung und Integration

### 1. INI-Konfiguration (OpenSim.ini oder Region.ini)

```ini
[WorldGenerator]
Enabled = true
Seed = 12345
HeightScale = 40.0
Frequency = 0.02
Octaves = 6
Lacunarity = 2.0
Gain = 0.5
MaxTrees = 5000
MaxBushes = 3000
ForestCoverage = 0.3
WaterLevel = 20.0
RiverCount = 3
LakeCount = 2
BiomeScale = 0.01
MaxSettlements = 5
SettlementDensity = 0.1
```

### 2. Kompilierung

Um dieses Modul zu kompilieren, müssen Sie die OpenSimulator-Assemblys referenzieren:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net462</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <Reference Include="OpenSim.Framework">
      <HintPath>path/to/opensim/bin/OpenSim.Framework.dll</HintPath>
    </Reference>
    <Reference Include="OpenSim.Region.Framework">
      <HintPath>path/to/opensim/bin/OpenSim.Region.Framework.dll</HintPath>
    </Reference>
    <!-- Weitere OpenSim-Referenzen -->
  </ItemGroup>
</Project>
```


---
---
---


## Erweiterungsmöglichkeiten

### 1. Erosion mit Hydraulic Erosion

```csharp
public class HydraulicErosion
{
    public void ApplyErosion(HeightMap heightmap, int iterations, float erosionRate, float depositionRate, float evaporationRate)
    {
        // Implementierung von hydraulischer Erosion
        // mit Wasserflusssimulation
    }
}
```

### 2. Straßengenerierung

```csharp
public class RoadGenerator
{
    public void GenerateRoads(Scene scene, HeightMap heightmap, List<Settlement> settlements)
    {
        // Generiere Straßen zwischen Siedlungen
        // mit A*-Pfadfindung unter Berücksichtigung des Terrains
    }
}
```

### 3. Siedlungsgenerierung

```csharp
public class SettlementGenerator
{
    public List<Settlement> GenerateSettlements(HeightMap heightmap, BiomeMap biomeMap)
    {
        // Platziere Siedlungen an geeigneten Orten
        // (in der Nähe von Wasser, flaches Terrain, etc.)
        return new List<Settlement>();
    }
}
```

### 4. Persistenz

```csharp
public class WorldPersistence
{
    public void SaveWorld(string worldName, HeightMap heightmap, BiomeMap biomeMap, List<TreeCluster> trees)
    {
        // Speichere Welt-Daten in Datenbank oder Datei
    }
    
    public WorldData LoadWorld(string worldName)
    {
        // Lade gespeicherte Welt
        return new WorldData();
    }
}
```

Dieses Grundgerüst bietet eine solide Basis für eine prozedurale Welterzeugungs-Engine in OpenSimulator. Es kann je nach Bedarf erweitert und angepasst werden.
