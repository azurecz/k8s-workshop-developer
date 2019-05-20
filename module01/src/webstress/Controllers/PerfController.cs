using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Documents;
using Microsoft.Azure.Documents.Linq;
using Microsoft.Azure.Documents.Client;
using Newtonsoft.Json;

namespace WebStress.Controllers
{
    [Route("api/[controller]")]
    public class PerfController : Controller
    {
        [HttpGet]
        [Route("/")]
        public async Task<IActionResult> Probe()
        {
            DateTime start = DateTime.Now;

            await calculateAsync(1);

            var ts = DateTime.Now - start;

            return Ok(string.Format("execution time: {0}ms", ts.TotalMilliseconds));
        }

        [HttpGet]
        [Route("/perf")]
        public async Task<IActionResult> Perf()
        {
            DateTime start = DateTime.Now;

            await calculateAsync(Repeats);

            var ts = DateTime.Now - start;

            start = DateTime.Now;
            var docid = await cosmosWrite(string.Format("{0}ms", ts.TotalMilliseconds));
            var tswrite = DateTime.Now - start;

            start = DateTime.Now;
            var docexists = await cosmosRead(docid);
            var tsread = DateTime.Now - start;

            return Ok(string.Format("exec: {0}ms | write: {1}ms | read: {2}ms ({3})\n",
                ts.TotalMilliseconds,
                tswrite.TotalMilliseconds,
                tsread.TotalMilliseconds,
                docexists ? "found" : "not-found"));
        }

        [HttpGet]
        [Route("/perf2")]
        public async Task<IActionResult> Perf2()
        {
            DateTime start = DateTime.Now;

            await calculateAsync(Repeats);

            var ts = DateTime.Now - start;

            start = DateTime.Now;
            var docid = await cosmosWrite2(string.Format("{0}ms", ts.TotalMilliseconds));
            var tswrite = DateTime.Now - start;

            start = DateTime.Now;
            var docexists = await cosmosRead2(docid);
            var tsread = DateTime.Now - start;

            return Ok(string.Format("exec: {0}ms | write: {1}ms | read: {2}ms ({3})\n",
                ts.TotalMilliseconds,
                tswrite.TotalMilliseconds,
                tsread.TotalMilliseconds,
                docexists ? "found" : "not-found"));
        }

        private async Task calculateAsync(int rounds)
        {
            await Task.Run(() => calculate(rounds));
        }

        private void calculate(int rounds)
        {
            {
                var sha1 = System.Security.Cryptography.SHA1.Create();

                byte[] hash = new byte[32];
                System.Security.Cryptography.RandomNumberGenerator.Create().GetBytes(hash);
                for (int i = 0; i < (256 * rounds); i++)
                {
                    hash = sha1.ComputeHash(hash);
                }
            }
        }

        public int Repeats
        {
            get
            {
                int ret = 1024;
                var tmp = Environment.GetEnvironmentVariable("CYCLECOUNT");
                var b = int.TryParse(tmp, out ret);
                if (!b || ret <= 0)
                {
                    ret = 1024;
                }
                return ret;
            }
        }

        public Uri CosmosDBUri
        {
            get
            {
                return new Uri(Environment.GetEnvironmentVariable("COSMOSURI"));
            }
        }

        public string CosmosDBKey
        {
            get
            {
                return Environment.GetEnvironmentVariable("COSMOSKEY");
            }
        }

        private ConnectionPolicy connPolicy
        {
            get
            {
                ConnectionPolicy ret = null;
                string loc = Environment.GetEnvironmentVariable("COSMOSLOCATION");
                if(loc!=null && loc!=string.Empty && loc.Length > 0)
                {
                    ret = new ConnectionPolicy();
                    ret.EnableEndpointDiscovery = true;
                    ret.PreferredLocations.Add(loc);
                }
                return ret;
            }
        }

        private static DocumentClient _cclient = null;
        private DocumentClient clientCosmos{
            get {
                if(_cclient==null){
                    _cclient = new DocumentClient(CosmosDBUri, CosmosDBKey, connPolicy);
                    _cclient.OpenAsync().GetAwaiter();
                }
                return _cclient;
            }
        }

        public class CosmosEntity
        {
            [Key]
            [JsonProperty("id")]
            public string Id { get; set; }
            [JsonProperty("runtime")]
            public string RunTime { get; set; }
            [JsonProperty("pkey")]
            public string PKey { get; set; }
        }

        private async Task<string> cosmosWrite(string runtime)
        {
            using (DocumentClient client = new DocumentClient(CosmosDBUri, CosmosDBKey, connPolicy))
            {
                await client.OpenAsync();
                Uri collectionLink = UriFactory.CreateDocumentCollectionUri("TestDB", "TestCollection");
                var data = new CosmosEntity();
                data.Id = Guid.NewGuid().ToString();
                data.PKey = data.Id.Substring(data.Id.Length - 3, 2);
                data.RunTime = runtime;
                ResourceResponse<Document> result = await client.CreateDocumentAsync(collectionLink, data);
                return data.Id;
            }
        }

        private async Task<bool> cosmosRead(string id)
        {
            using (DocumentClient client = new DocumentClient(CosmosDBUri, CosmosDBKey, connPolicy))
            {
                await client.OpenAsync();
                Uri collectionLink = UriFactory.CreateDocumentCollectionUri("TestDB", "TestCollection");
                var data = from d in client.CreateDocumentQuery<CosmosEntity>(collectionLink, new FeedOptions { EnableCrossPartitionQuery = true })
                           where d.Id == id
                           select d;
                return (data.ToList().Count>0);
            }
        }

        private async Task<string> cosmosWrite2(string runtime)
        {
            Uri collectionLink = UriFactory.CreateDocumentCollectionUri("TestDB", "TestCollection");
            var data = new CosmosEntity();
            data.Id = Guid.NewGuid().ToString();
            data.PKey = data.Id.Substring(data.Id.Length - 3, 2);
            data.RunTime = runtime;
            ResourceResponse<Document> result = await clientCosmos.CreateDocumentAsync(collectionLink, data);
            return data.Id;
        }

        private async Task<bool> cosmosRead2(string id)
        {
            Uri collectionLink = UriFactory.CreateDocumentCollectionUri("TestDB", "TestCollection");
            using(var data = clientCosmos.CreateDocumentQuery<CosmosEntity>(collectionLink, new FeedOptions { EnableCrossPartitionQuery = true })
                        .Where(d => d.Id == id)
                        .AsDocumentQuery())
            {
                var ret = false;
                while (data.HasMoreResults) 
                {
                    foreach(CosmosEntity b in await data.ExecuteNextAsync<CosmosEntity>())
                    {
                        ret = true;
                    }
                }
                return ret;
            }            
        }

    }
}
