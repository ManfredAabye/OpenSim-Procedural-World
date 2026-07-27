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