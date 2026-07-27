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