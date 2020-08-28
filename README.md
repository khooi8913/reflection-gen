# reflection-gen

## Overview
This script is written to work with MoonGen. It is assumed that MoonGen is installed.

The source IPs of the reflection attack is randomly generated and selected during traffic generation. For each packet, the destinatio port will be randomly selected within the ephemeral port range (i.e., for Linux, 32768-60999).

## Usage 
```
Usage: libmoon ../reflection-gen/reflection-gen.lua [-r <rate>] [-t <threads>] [-f <sources>] [-p <port>] [-h] [<dev>] ...
```

## Contribution/ Feedback
If you have any comments/ questions/ feedback, feel free to file an issue!