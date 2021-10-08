
   
from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("example.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");
 
    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.NEIGHBOR_CHANNEL);

    s.runTime(5);

    for i in range(1, 5):
        s.runTime(5);
        s.neighborDMP(i);

    s.runTime(5);

    #s.neighborDMP(1);
    s.runTime(5);

    #s.moteOff(3);
    #s.runTime(15);

   # s.neighborDMP(5);
   # s.runTime(5);

if __name__ == '__main__':
    main()
