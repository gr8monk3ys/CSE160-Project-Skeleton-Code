from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("long_line.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);
    s.addChannel(s.ROUTING_CHANNEL);

    # Regular routing test
    s.runTime(100);

    for i in range(1, 10):
        s.routeDMP(i);
        s.runTime(5);

    s.ping(2, 9, "Test");
    s.runTime(5);
    
    # Test routing with a suddenly invalidated path
    s.moteOff(3);
    s.runTime(100);

    s.routeDMP(2);
    s.runTime(5);

    s.routeDMP(9);
    s.runTime(5);

    s.ping(2, 9, "Test");
    s.runTime(5);

if __name__ == '__main__':
    main()
