import asyncio
import env_canada 


from env_canada import ECWeather

ec = ECWeather(station_id="QC/s0000616", language="english")

asyncio.run(ec.update())

# current
print(ec.conditions)

