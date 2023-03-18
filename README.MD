# Fennec 6800 Video Terminal Interface (VTI) Expansion

This expansion board is designed for use with the [Fennec 6800 SBC](https://github.com/ChartreuseK/Fennec6800). It provides a 64 column by 16 line video display over composite ("NTSC") video or a CGA compatible monitor. In addition to the video display it also provides for a parallel ASCII keyboard interface on either a DIP14 IDC header, or over a DA-15 connector. Combined with an Option ROM that hooks into the Fennec 6800's BIOS, this provides for a full video terminal interface for the Fennec, negating the need for an external terminal on the first serial port. 

Connection to the Fennec is accomplished by a 1:1 wired 40 pin IDC cable between the two, multiple expansions may be attached to the bus using such a straight through wired cable. A common 40 pin IDE cable with no key plug may be used for this purpose, however an 80 pin IDE cable should never be used as they internally connect many pins to ground.

Through the use of a 6845 VDP, and socketed crystal, the interface can be reprogrammed to a number of different possible graphics modes. With 2kB of VRAM provided by a 6116/4016 SRAM, the interface can support up to 80x25 text mode when combined with an appropriate dot clock and an 8x8 font. Using a larger font ROM than the 2716 is also possible, with up to 32kB of font ROM being possible, allowing for extra tall and detailed characters. However due to non-interlaced composite video's vertical line count this will result in significantly less lines displayed. 

The ASCII keyboard interface is provided via a 6820/6821/6521 PIA, giving a full 8-bit ASCII interface with strobe to the keyboard. The second 8-bit port of the PIA is not used and is provided on a pin header for the user to experiment with and control. In addition a small prototyping area is available on the right hand side of the card to be used for such experiments.

Only 5v is provided to the keyboard, so vintage keyboards requiring extra voltages such as -12v will need to be supplied that externally. 
