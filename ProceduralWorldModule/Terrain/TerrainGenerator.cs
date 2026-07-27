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