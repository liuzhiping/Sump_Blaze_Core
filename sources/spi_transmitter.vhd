----------------------------------------------------------------------------------
-- spi_transmitter.vhd
--
-- Copyright (C) 2006 Michael Poppitz
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or (at
-- your option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program; if not, write to the Free Software Foundation, Inc.,
-- 51 Franklin St, Fifth Floor, Boston, MA 02110, USA
--
----------------------------------------------------------------------------------
--
-- Details: http://www.sump.org/projects/analyzer/
--
-- Takes 32bit (one sample) and sends it out on the SPI port.
-- End of transmission is signalled by taking back the busy flag.
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity spi_transmitter is
	port(
		data : in std_logic_vector (31 downto 0);
		tx_bytes : in integer range 0 to 4;
		send : in std_logic;
		clock : in std_logic;
		sclk : in std_logic;
		tx : out std_logic := '0';
		cs : in std_logic;
		busy: out std_logic := '0';
		dataReady : out std_logic := '0'
	);
end spi_transmitter;

architecture behavioral of spi_transmitter is

	type states is (IDLE, START, WAIT_CS_LO, SEND_BITS, WAIT_CS_HI);

	signal tx_buf : std_logic_vector (31 downto 0) := (others => '0');
	signal bits : integer range 0 to 7;
	signal bytes, end_byte : integer range 0 to 4;
	signal rsync_sclk, rsync_cs : std_logic_vector(1 downto 0) := (others => '0');
	signal state: states;

begin

	process(clock)
	begin
		if rising_edge(clock) then

			rsync_sclk <= rsync_sclk(0) & sclk;
			rsync_cs <= rsync_cs(0) & cs;

			case state is
				when IDLE =>
					if send = '1' then
						state <= START;
						busy <= '1';
						dataReady <= '1';
					end if;
					tx_buf <= data(7 downto 0) & data(15 downto 8) 
							& data(23 downto 16) & data(31 downto 24);
					end_byte <= tx_bytes;
					bytes <= 0;
					bits <= 0;
				when START =>
					-- tx starts at cs falling edge
					if rsync_cs = "10" then
						state <= WAIT_CS_LO;
						tx <= tx_buf(31);
					end if;
				when WAIT_CS_LO =>
					-- wait for cs before sending the next byte
					if cs = '0' and rsync_sclk = "10" then
						state <= SEND_BITS;
						tx_buf <= tx_buf(30 downto 0) & '0';
						bytes <= bytes + 1;
					elsif bytes = end_byte then
						state <= WAIT_CS_HI;
						dataReady <= '0';
					end if;
					tx <= tx_buf(31);
				when SEND_BITS =>
					-- transfer bits at falling edge of sclk
					if rsync_sclk = "10" then
						tx_buf <= tx_buf(30 downto 0) & '0';
						bits <= bits + 1;
					elsif bits = 7 then
						state <= WAIT_CS_LO;
						bits <= 0;
					end if;
					tx <= tx_buf(31);
				when WAIT_CS_HI =>
					-- tx stops until cs rising edge
					if rsync_cs = "01" then
						state <= IDLE;
						busy <= '0';
					end if;
			end case;

		end if;
	end process;

end behavioral;
