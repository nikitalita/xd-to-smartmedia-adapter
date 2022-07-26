;***************************************************************************
;
; File Name		:'SmartM.asm"
; Title			:SmartMedia Driver for External SMIL Controller
; Date			:2003.05.05.
; Version		:1.11.0
; Support telephone	:+36-70-333-4034,  old: +36-30-9541-658 VFX
; Support fax		:
; Support Email		:info@vfx.hu
; Target MCU		:ATmega128
;
;***************************************************************************
;	D E S C R I P T I O N
;
; VFX SMIL Smart Media Manager
;
;Why is FTL needed?
;	• Flash are not 100% perfect . It needs bad block management.
;	• Flash is erased in blocks(typical 16KB) larger than disk sectors(512Byte)
;	• Flash has a limited number of erase cycles (1M Cycles). So it needs wear-leveling algorithm.
;	• Flash is essentially non-writable (must be erased before it can be written)
;
;	· Converts the sector addresses addressed by the host to physical addresses of Flash Memory
;	· Converts host requests into the programming/erasing algorithms of associated Flash technology
;	· Detects the error and replaces the encountered bad sectors with the good by mapping them out
; --------------------------------------------------------------------------------------
;                          Linear address			  Logical Address
;		- Address Map, Address Configuration
; 		I/O0 I/O1 I/O2 I/O3 I/O4 I/O5 I/O6 I/O7
;1st Cycle 	  A0   A1   A2   A3   A4   A5   A6   A7		CA0 ~ CA7 : column address
;2nd Cycle	  A9  A10  A11  A12  A13  A14  A15  A16		PA0 ~ PA7 : page address 1
;3rd Cycle	 A17  A18  A19  A20  A21  A22  A23  A24		PA8 ~ PA15 : page address 2
;4th Cycle	 A25  A26					PA16 ~ PA23 : page address 3
;
;Model	Valid Page Address	 Fixed Low
;2MB	PA0 ~ PA12		 PA13 ~ PA15
;4MB	PA0 ~ PA12		 PA13 ~ PA15
;8MB	PA0 ~ PA13		 PA14 ~ PA15
;16MB	PA0 ~ PA14		 PA15
;32MB	PA0 ~ PA15		 -
;64MB	PA0 ~ PA16		 PA17 ~ PA23
;128MB	PA0 ~ PA17		 PA18 ~ PA23
;
; --------------------------------------------------------------------------------------
; Considerations for High Density Considerations for High Density SmartMedia
; Zone-based block management for 32MB,64MB and 128MB
;
;Zone	Physical		 Block Description
; 0	0			 CIS/Identify Drive Information Area
; 0	1 ~ 1023		 Data Area (Logical Block : 0 ~ 999)
; 1	0 ~ 1023		 Data Area (Logical Block :1000 ~1999)
; ...
; Last  0 ~ 1023		 Data Area (Logical Block : Zone x 1000 + 999 )
;
;* CIS/Identify Drive Information Area ==>Zone 0
;  Each zone has 1000 data blocks.
; --------------------------------------------------------------------------------------
;
; CIS (Card Information System) Area 1 and CIS (Card Information System) Area (1 and 2) Physical BLOCK 1
;
;Addr	Data	 Contents
;
;00	01h      Tuple ID(CIS TPL_Device)
;01     03h      Link to Next Tuple
;02     D9h      Device Type : I/O, Rate : 250ns
;03	01h      Device Size : 2 K Byte
;04	FFh      End of Device ID Tuple
;05	01h      Tuple ID(CIS TPL_JEDEC_C)
;06	20h      Link to Next Tuple
;07	DFh      JEDEC Manufacture ID(PC Card ATA)
;08     18h      JEDEC Device ID(VPP not required)
;09     02h      Tuple ID(CIS TPL_MANF ID)
;0A     04h      Link to Next Tuple
;0B     00h      Manufacture Code
;0C     00h      Manufacture Code
;0D     00h      Manufacture Info.
;0E     00h      Manufacture Info.
;0F     21h      Tuple ID(CIS TPL_FUNC ID)
;10     02h      Link to Next Tuple
;11     04h      PL FID_FUNCTION
;12     01h      TPL_FID_SYS INIT
;13     22h      Tuple ID(CIS TPL_FUNCE)
;14     02h      Link to Next Tuple
;15     01h      Disk Device Interface Tuple
;16     01h      PC Card ATA Interface
;17     22h      Tuple ID(CIS TPL_FUNCE)
;18     03h      Link to Next Tuple
;19     02h      PC Card ATA Extension Tuple
;1A     04h      ATA Function Byte1
;1B     07h      ATA Function Byte2
;1C     1Ah      Tuple ID(CIS TPL_CONFIG)
;1D     05h      Link to Next Tuple
;1E     01h      Field Size Byte
;1F     03h      Last Entry in the Card Configuration Table
;20     00h      CCR Base Address(Low-order Byte)
;21     02h      CCR Base Address(High-order Byte)
;22     0Fh      CCR Present Mask
;23     1Bh      Tuple ID(CIS TPL_CFTABLE_ENTRY)
;24     08h      Link to Next Tuple
;25     C0h      Configuration Table Index Byte
;26     C0h      Interface Description Field
;27     A1h      Feature Selection Byte
;28     01h      Power Parameter Selection Byte
;29     55h      Power Voltage(5V)
;2A     08h      Memory Space(Low-order byte)
;2B     00h      Memory Space(High-order byte)
;2C     20h      Miscellaneous (ex: CCSR power down)
;2D     1Bh      Tuple ID(CIS TPL_CFTABLE_ENTRY)
;2E     0Ah      Link to Next Tuple
;2F     C1h      Configuration Table Index Byte
;30     41h      Interface Description Field
;31     99h      Feature Selection Byte
;32     01h      Power Parameter Selection Byte
;33     55h      Power Voltage(5V)
;34     64h      I/O Space Description Byte
;35     F0h      Interrupt IRQ Condition Info.
;36     FFh      Interrupt IRQs 0 to 7
;37     FFh      Interrupt IRQs 8 to 15
;38     20h      Miscellaneous (ex: CCSR power down)
;39     1Bh      Tuple ID [I/O Primary]
;3A     0Ch      Link to Next Tuple
;3B     82h      Configuration Table Index Byte
;3C     41h      Interface Description Field
;3D     18h      Feature Selection Byte
;3E     EAh      I/O Space Description Byte
;3F     61h      I/O Range Description Byte
;40     F0h      I/O Address Range(01F0h-01F7h)
;41     01h      I/O Address Range(01F0h-01F7h)
;42     07h      8 Bytes
;43     F6h      I/O Address Range(03F6h-03F7h)
;44     03h      I/O Address Range(03F6h-03F7h)
;45     01h      2 Bytes
;46     EEh      IRQ Condition Info. (IRQ14)
;47     1Bh      Tuple ID[I/O secondary]
;48     0Ch      Link to Next Tuple
;49     83h      Configuration Table Index Byte
;4A     41h      Interface Description Field
;4B     18h      Feature Selection Byte
;4C     EAh      I/O Space Description Byte
;4D     61h      I/O Range Description Byte
;4E     70h      I/O Address Range(0170h-0177h)
;4F     01h      I/O Address Range(0170h-0177h)
;50     07h      8 Bytes
;51     76h      I/O Address Range(0376h-0377h)
;52     03h      I/O Address Range(0376h-0377h)
;53     01h	 2 Bytes
;54     EEh      IRQ Condition Info. (IRQ14)
;55     15h      Tuple ID(CIS TPL_VERS_1)
;56     14h      Link to Next Tuple
;57     05h      Major Version Number[Ver.5]
;58     00h      Minor Version Number[Ver.0]
;59     20h      Name of Manufacture
;5A     20h      Name of Manufacture
;5B     20h      Name of Manufacture
;5C     20h      Name of Manufacture
;5D     20h      Name of Manufacture
;5E     20h      Name of Manufacture
;5F     20h      Name of Manufacture
;60     00h      End of Manufacture Name
;61     20h      Name of Product
;62     20h      Name of Product
;63     20h      Name of Product
;64     20h      Name of Product
;65     00h      End of Product Name
;66     30h      Product Version �0�
;67     2Eh      Product Version "."
;68     30h      Product Version "0"
;69     00h      End of Product Version
;6A     FFh      End of Product Info. Tuple
;6B     14h      CIS TPL_NO_LINK
;6C     00h      Link to Next Tuple
;6D     FFh      CIS TPL_END
;6E-7F  00h      Null-Tuple
;
; --------------------------------------------------------------------------------------
;
;  Logical Format Parameter
;
;	      		1 MB	2 MB	4 MB	8 MB	16 MB	32 MB	64 MB	128 MB
;NumCylinder		125	125	250	250	500	500	500	500
;NumHead 		4	4	4	4	4	8	8	16
;NumSector		4	8	8	16	16	16	32	32
;SumSector		2,000	4,000	8,000	16,000	32,000	64,000	128,000	256,000
;SectorSize		512	512	512	512	512	512	512	512
;Logical Block Size     4k      4k      8k      8k      16k	16k	16k	16k
;Unformatted		1MB	2MB	4MB	8MB	16MB	32MB	64MB	128MB
;Formatted              0.977MB	1.953MB	3.906MB	7.813MB	16.63MB	31.25MB	62.5MB	125MB
;
;   Physical Format Parameter
;
;Page Size (byte)       256+8	256+8   512+16	512+16	512+16	512+16	512+16	512+16	(byte/sectror)
;Number of page/block	?	16	16	16	32	32	32	32	(sectror/Cluster)
;Number of block/device	?	512	512	1024	1024	2048	4096	8192	(Cluster)




; --------------------------------------------------------------------------------------
;	Sector Data Structure
;	[1 Sector = 1 Page]
;	0-255	   Data Area-1
;	256-511	   Data Area-2
;
; 	Spare Area Information (4 ~ 128 MB)
;	512-515	   Reserved Area
;	516	   Data/User Status Flag/Area
;	517	   Block Status Flag/Area
;	518-519	   Block Address Area-1
;	520-522	   ECC Area-2
;	523-524	   Block Address Area-2
;	525-527	   ECC Area-1
;
; --------------------------------------------------------------------------------------
;	Block Address Area Information
;	[Block Address Configuration]
;D7  D6  D5  D4  D3  D2  D1  D0		1,2 MB SM	4,8,16 MB and above SM
;
;0   0   0   1   0   BA9 BA8 BA7 	262 bytes(even)	518, 523 bytes
;					259 bytes(odd)
;
;BA6 BA5 BA4 BA3 BA2 BA1 BA0 P          263 bytes(even) 519, 524 bytes
;					260 bytes(odd)
;
;BA9 ~ BA0 : Block Address (values=0 through n,where n = maximum logical block count - 1)
;P : Even Parity bit
;
; --------------------------------------------------------------------------------------
; Block_a Parameter Definition
; - Used Valid Block is block_a[ Physical block number] = bl_addr(Block Address value)
; - Invalid Block is block_a[Physical block number] = 0xffee(Invalid Mark is defined as � 0xffee� )
; - CIS Block is block_a[Physical block number] = 0 (Actual Block Addess Value is � 0x0000� .)
; - Unused Valid Block[Physical block number] = 0xffff
;
; --------------------------------------------------------------------------------------
;
; Support Devices
;  K9S2808V0M-SSB0	16M x 8 bit SmartMedia Card - tested
;			[32768 rows(pages), 528 columns]
;
;
; Command Latch Enable(CLE)
;	The CLE input controls the path activation for commands sent to the
;	command register. When active high, commands are latched into the
;	command register through the I/O ports on the rising edge of the
;	WE signal.
;
; Address Latch Enable(ALE)
;	The ALE input controls the activating path for address to the internal
;	address registers. Addresses are latched on the rising edge of WE with
;	ALE high.
;
; Chip Enable(CE)
;	The CE input is the device selection control. When CE goes high during
;	a read operation the device is returned to standby mode.
;	However, when the device is in the busy state during program or erase,
;	CE high is ignored, and does not return the device to standby mode.
;
; Write Enable(WE)
;	The WE input controls writes to the I/O port. Commands, address and data
;	are latched on the rising edge of the WE pulse.
;
; Read Enable(RE)
;	The RE input is the serial data-out control, and when active drives the
;	data onto the I/O bus. Data is valid tREA after the falling edge of RE
;	which also increments the internal column address counter by one.
;
; I/O Port : I/O 0 ~ I/O 7
;	The I/O pins are used to input command, address and data, and to output
;	data during read operations. The I/O pins float to high-z when the chip
;	is deselected or when the outputs are disabled.
;
; Write Protect(WP)
;	The WP pin provides inadvertent write/erase protection during power
;	transitions. The internal high voltage generator is reset when the
;	WP pin is active low.
;
; Ready/Busy(R/B)
;	The R/B output indicates the status of the device operation. When low,
;	it indicates that a program, erase or random read operation is
;	in process and returns to high state upon completion. It is an open
;	drain output and does not float to high-z condition when the chip
;	is deselected or when outputs are disabled.
;
;
;***************************************************************************
;	M O D I F I C A T I O N   H I S T O R Y
;
;
;       rev.      date      who  	why
;	----	----------  ---		------------------------------------
;	0.01	2002.07.19  VFX		Creation
;	1.10	2003.02.02  VFX		Redesign all functions
;	1.11	2003.05.05  VFX		Remove IO pin and change to XMEM mode
;
;***************************************************************************
;Hardware
;***************************************************************************
;*
;*	SYSCLK: f=16.000 MHz (T= 62.5 ns)
;*
;***************************************************************************
;
;


;***************************************************************************
;* Const Def

	;SmartMedia Commands
.EQU	SM_ReadLowHalf		= 0x00h			;Page read A
.EQU	SM_ReadHiHalf		= 0x01h
.EQU	SM_ReadEnd		= 0x50h			;Page read C
.EQU	SM_ReadID		= 0x90h			;Read ID
.EQU	SM_ReadUnique		= 0x91h			;Read Unique 128 bit
.EQU	SM_Reset		= 0xFFh			;Device reset
.EQU	SM_PageProgram		= 0x80h			;Ready to write, Serial Data Input
.EQU	SM_PageProgramTrue	= 0x10h			;Start to write page, auto program (Toshiba)
.EQU	SM_PageProgramDumy	= 0x11h			;
.EQU	SM_PageProgramMultiBlk	= 0x15h			;
.EQU	SM_BlockErase		= 0x60h			;Erase block (block#)
.EQU	SM_BlockErase2nd	= 0xD0h			;Erase block (start)
.EQU	SM_ReadStatus		= 0x70h			;Read status
.EQU	SM_ReadMultiPlaneStatus	= 0x71h			;

	;SMIL Commands

.equ	SMIL_Standby		= 0x00h ;Standby Mode

.equ	SMIL_RM_ReadData	= 0x14h ;Data Read     ( SmartMedia Data Read )
.equ	SMIL_RM_WriteCmd	= 0x15h ;Command Write ( SmartMedia Data Read )
.equ	SMIL_RM_WriteAddr	= 0x16h	;Address Write ( SmartMedia Data Read )
.equ	SMIL_RM_WriteData	= 0x14h ;Data Write    ( SmartMedia Data Read )


.equ	SMIL_WM_ReadData	= 0x94h ;Data Read     ( SmartMedia Data Write)
.equ	SMIL_WM_WriteCmd	= 0x95h ;Command Write ( SmartMedia Data Write)
.equ	SMIL_WM_WriteAddr	= 0x96h	;Address Write ( SmartMedia Data Write)
.equ	SMIL_WM_WriteData	= 0x94h ;Data Write    ( SmartMedia Data Write)

.equ	SMIL_ResetECCLogic	= 0b01100000
.equ	SMIL_RWwithECC		= 0b00100000
.equ	SMIL_RWwithoutECC	= 0b00000000




	;SM Manufacturer ID
.equ	MakerSamsung = 0xEC
.equ	MakerToshiba = 0x98



	;SM IDs,  only 3.3V or 2.7-3.6V devices
.equ	Sign05	= 0xA4		;0.5 Mb
.equ	Sign1	= 0x6E		;1 Mb
.equ	Sign2	= 0xEA		;2 Mb Samsung
.equ	Sign2a	= 0x64		;2 Mb Toshiba
.equ    Sign4	= 0xE3		;4 MB Samsung
.equ    Sign4a	= 0xE5		;4 MB Toshiba
.equ    Sign8	= 0xE6		;8 Mb
.equ    Sign16	= 0x73		;16 MB
.equ    Sign32	= 0x75		;32 Mb
.equ    Sign64	= 0x76		;64 Mb
.equ    Sign128	= 0x79		;128 Mb


.EQU	SM_UniqueIDcode	     = 0xA5
.EQU	SM_MultiplaneSupportCode = 0xC0
.equ	ExtendedID   = 0x21


.equ	SM_Protected = 7				;bit = 1, media write protect
.equ	SM_Busy	     = 6				;bit = 1, media ready
.equ	SM_Fail	     = 0				;bit = 1, Fail

;SmFlags
.EQU	SM_UniqueID	     = 7
.EQU	SM_MultiplaneSupport = 6
.EQU	SM_DeviceTooSmall     = 5			;Device < 16 MB
.EQU	SM_DeviceUnkown	     = 4			;Device Unknown


.equ	W500us	= SYSCLK/8000	;Delay 500us units of  SYSCLK
.equ	W10us	= SYSCLK/160    ;Delay 10us

;**************************************************************************
;* Hardware Def.
;

; External Controller Address def. by main.asm
;.equ	ADR_SMDATA = 0x3F00		;SmartMedia Data Register
;.equ	ADR_SMMODE = 0x3F01		;SmartMedia Mode Register
;.equ	ADR_SMSTAT = 0x3F01		;SmartMedia Mode Register



;***************************************************************************
;**** VARIABLES
.DSEG

;-Memory Card-----------Egymas utan kell aljanak -- Struct
;dont remove or insert any line here!!
SmManufacturerID: .byte 1		; SM Manufacturer code
SmDeviceCode:	  .byte	1		; SM Device Code
SmFlags:	  .byte 1		; 7 bit = 1 UniqueID Supported
					; 6 bit = 1 MultiPlane Supported
SmPages:	  .byte	3 		; Number of pages (physical sectors)
SmPPB:		  .byte	1 		; Pages per block
SmBlocks:	  .byte 2		; Blocks per Devices

;end struct

SMDataBuffer:	  .byte 512		;I/O Data buffer


;***************************************************************************
.ESEG


;***************************************************************************
;**** CODE SEG
;***************************************************************************
.CSEG

Init_SMedia:
		ldi	R16, SMIL_Standby
		sts     ADR_SMMODE,R16		;SmartMedia Controller is StandBy

		clr	R16
		sts	SmManufacturerID,R16	;No valid Card in socket
		sts	SmDeviceCode,R16
		sts	SmFlags,R16

		rcall	SM_ResetDevice		;Reset SmartMedia

PrintSMType:
		rcall	SM_GetType		;Get SmartMedia Type

		lds	R18,SmFlags
		andi	R18,(1<<SM_DeviceUnkown)
		breq	ValidCard

		ldi	R16,Low(SMStr1)
		ldi	R17,High(SMStr1)
		call	SendStrW
		ret
ValidCard:
		ldi	R16,Low(SMStr2)
		ldi	R17,High(SMStr2)
		call	SendStrW

		ldi	R16,Low(SMStr3)
		ldi	R17,High(SMStr3)
		call	SendStrW

		ldi	R16,Low(SMStr4)
		ldi	R17,High(SMStr4)
		lds	R18,SmManufacturerID
		cpi	R18,MakerSamsung
		breq	SMMOK

		ldi	R16,Low(SMStr5)
		ldi	R17,High(SMStr5)
		cpi	R18,MakerSamsung
		breq	SMMOK

		ldi	R16,Low(SMStr6)
		ldi	R17,High(SMStr6)
SMMOK:
		call	SendStrW

		ldi	R16,Low(SMStr7)
		ldi	R17,High(SMStr7)
		call	SendStrW


		ldi	R16,Low(SMStr8)
		ldi	R17,High(SMStr8)
		lds	R18,SmFlags
		andi	R18,(1<<SM_DeviceTooSmall)
		brne	SMSize


		lds	R18,SmDeviceCode
		ldi	R16,Low(SMStr16)
		ldi	R17,High(SMStr16)
		cpi	R18,Sign16
		breq	SMSize

		ldi	R16,Low(SMStr32)
		ldi	R17,High(SMStr32)
		cpi	R18,Sign32
		breq	SMSize

		ldi	R16,Low(SMStr64)
		ldi	R17,High(SMStr64)
		cpi	R18,Sign64
		breq	SMSize

		ldi	R16,Low(SMStr128)
		ldi	R17,High(SMStr128)
		cpi	R18,Sign128
		breq	SMSize

		ldi	R16,Low(SMStr6)
		ldi	R17,High(SMStr6)

SMSize:
		call	SendStrW

		ldi	R16,Low(SMStr9)
		ldi	R17,High(SMStr9)
		lds	R18,SmFlags
		andi	R18,(1<<SM_DeviceTooSmall)
		brne	UIDSup
		ldi	R16,Low(SMStr10)
		ldi	R17,High(SMStr10)
UIDSup:
		call	SendStrW

		ldi	R16,Low(SMStr11)
		ldi	R17,High(SMStr11)
		lds	R18,SmFlags
		andi	R18,(1<<SM_MultiplaneSupport)
		brne	MultiSup
		ldi	R16,Low(SMStr12)
		ldi	R17,High(SMStr12)
MultiSup:
		call	SendStrW
		ldi	R16,CR
		call	SendChrW
		ret

SMStr1:		.db	"SmartMedia not found. ",CR,0
SMStr2:		.db	"SmartMedia found. ",CR,0
SMStr3:		.db	"Manufacturer:",0
SMStr4:		.db	" Samsung",CR,0
SMStr5:		.db	" Toshiba",CR,0
SMStr6:		.db	" Unknown",CR,0
SMStr7:		.db	"Size:",0
SMStr8:		.db	" <16MB unusable ",CR,0
SMStr9:		.db	"Unique ID supported ",CR,0
SMStr10:    	.db	"Unique ID not supported ",CR,0
SMStr11:	.db	"Multiplane supported",CR,0
SMStr12:	.db	"Multiplane not supported",CR,0
SMStr16:	.db	" 16Mb ",CR,0
SMStr32:	.db	" 32Mb ",CR,0
SMStr64:	.db	" 64Mb ",CR,0
SMStr128:	.db	"128Mb ",CR,0

;***************************************************************************
; SM_ResetDevice
; SM - Get SM type and initialize SM properties
;
; In: -
; Out:  c=0 successfull
;	c=1 unsuccessfull, Meadia Removed!
; Alt:  R16, XL, XH
;
SM_ResetDevice:
		ldi	R16,SMIL_RM_WriteCmd		; CE="L" ,Command Phase: CLE="H", ALE="L"
		sts	ADR_SMMODE,R16
		ldi	R16,SM_Reset			; Cmd: Reset
		sts	ADR_SMDATA,R16

		ldi	XL,low(W500us/9) 		;max t(res)=500us varkozas, ha timeout, akkor nincs eszkoz
	     	ldi	XH,high(W500us/9)
SMResWait:
		sbiw	XL,1				;[2]
		breq	SMResTimeOut			;[1, doesnt need jump]
		lds	R16,ADR_SMSTAT			;[3, external sram]
		sbrs	R16,7				;[1] Wait for R/B pin
		  rjmp	SMResWait			;[2], = total 9 cycles
		ldi	R16,SMIL_Standby
		sts	ADR_SMMODE,R16
		clc
		ret
SMResTimeOut:
		ldi	R16,SMIL_Standby
		sts	ADR_SMMODE,R16
		sec
		ret


; SM properties
;
SMProp:	.db 0x00, 0x80, 0x00, 32, 0x00, 0x04	;Sign16	= 0x73,   32768 sector, 32 sector/block, 1024 block == 16Mb
SMNext:	.db 0x00, 0x00, 0x01, 32, 0x00, 0x08	;Sign16	= 0x75,   65536 sector, 32 sector/block, 2048 block == 32Mb
	.db 0x00, 0x00, 0x02, 32, 0x00, 0x10	;Sign16	= 0x76,  131072 sector, 32 sector/block, 4096 block == 64Mb
	.db 0x00, 0x00, 0x04, 32, 0x00, 0x20	;Sign16	= 0x79,  262144 sector, 32 sector/block, 8192 block == 128Mb


;***************************************************************************
; SM_GetType
; SM - Get SM type and initialize SM properties
;
; In: -
; Out:  C=0: successful, SmPages are valid
;       C=1: unknown type
SM_GetType:
 		ldi	ZL,low(SMProp*2)
		ldi	ZH,high(SMProp*2)
 		ldi	XL,low(SmManufacturerID)
		ldi	XH,high(SmManufacturerID)

		ldi	R16,SMIL_RM_WriteCmd		; CE="L", Command Phase: CLE="H", ALE="L"
		sts	ADR_SMMODE,R16
		ldi	R16,SM_ReadID   		; Cmd: Read ID
		sts	ADR_SMDATA,R16

		ldi	R16,SMIL_RM_WriteAddr		; Address Phase: CLE="L", ALE="H"
		sts	ADR_SMMODE,R16
		ldi	R16,0x00			; Addr: 0
		sts	ADR_SMDATA,R16
		ldi	R16,SMIL_RM_ReadData
		sts	ADR_SMMODE,R16			;Data Read Mode
		nop
		nop					;t(CR) & t(AR1) <= 100ns, ezt kivarjuk 2 NOPpal

		lds	R16,ADR_SMDATA			; Read mfr code
		st	X+,R16
		lds	R16,ADR_SMDATA			; Read device code
		st	X+,R16
		clr	R16
		st	X,R16				;SMFlags torolve
		lds	R16,ADR_SMDATA			;Read UniqueID code
		cpi	R16,SM_UniqueIDcode
		brne	SMNotUniqueID
		ld	R16,X
		ori	R16,(1<<SM_UniqueID)		;Unique ID Supported
		st	X,R16
SMNotUniqueID:
		lds	R16,ADR_SMDATA			; Read Multiplane Support
		cpi	R16,SM_MultiplaneSupportCode
		brne	SMNotMultiPlane
		ld	R16,X
		ori	R16,(1<<SM_MultiplaneSupport)
		st	X,R16
SMNotMultiPlane:
		adiw	XL,1				; X points to SmPages

		lds	R16,SmDeviceCode
		cpi	R16,Sign16
		breq	SMHit
      		adiw	ZL,(SMNext-SMProp)*2
		cpi	R16,Sign32
		breq	SMHit
      		adiw	ZL,(SMNext-SMProp)*2
		cpi	R16,Sign64
		breq	SMHit
      		adiw	ZL,(SMNext-SMProp)*2
		cpi	R16,Sign128
		breq	SMHit

		cpi	R16,Sign05
		breq	SMTooSmal
		cpi	R16,Sign1
		breq	SMTooSmal
		cpi	R16,Sign2
		breq	SMTooSmal
		cpi	R16,Sign2a
		breq	SMTooSmal
		cpi	R16,Sign4
		breq	SMTooSmal
		cpi	R16,Sign4a
		breq	SMTooSmal
		cpi	R16,Sign8
		breq	SMTooSmal
						;ha ide jutott, akkor ismeretlen eszkoz
						;unknown device
		lds	R16,SmFlags
		ori	R16,(1<<SM_DeviceUnkown)
       		rjmp	SMErr1

SMTooSmal:					;ismert, de tull kicsi eszkoz  size<16MB
		lds	R16,SmFlags
		ori	R16,(1<<SM_DeviceTooSmall)
SMErr1:		sts	SmFlags,R16
		clr	R16
		sts	SmPPB,R16
		sts	SmBlocks+0,R16
		sts	SmBlocks+1,R16  	;SmPages nem kell feltolteni 0-val!

		ldi	R16,SMIL_Standby
		sts	ADR_SMMODE,R16
		sec
		ret
SMHit:						;Valid device
		ldi	R16,(SMNext-SMProp)*2
SMFillProp:	lpm
		adiw	ZL,1
		st	X+,R0
		dec	R16
		brne	SMFillProp
		ldi	R16,SMIL_Standby
		sts	ADR_SMMODE,R16
		clc
		ret


;***************************************************************************
; SM_RD_Page2, SM_RD_Page1, SM_RD_Page
; Read out a page data from memory array into transfer buffer
;
; In: R13:R12:R11:R10 page address (R13 MSB)
; Out: SMCE = "L"
;       c=0, read succesfull
;	c=1, TimeOut error
; Alt: R3, R16, R17
;
; NOTE1: AT 32MB MEDIUM OR BELOW.
; The read transfer cycle is initiated after Addr2, following Addr3 will
; be ignored. But if Addr3 is given at the read transfer cycle has been
; completed, read data can become wrong. An interrupt between Addr2 and
; Addr3 will cause this problem. Therefore, all interrupts must be disabled
; during this routine is executed in order to avoid data collaption.

; az adat kiolvasasa utan CE-t magasba kell tolni!

SM_RD_Page2:		  			; Read a page and set pointer to offset 512
		ldi	R16,SM_ReadEnd		; Cmd: Read2
		rjmp    SM_PageRead
SM_RD_Page1:
		ldi	R16,SM_ReadHiHalf	; Read a page and set pointer to offset 256
		rjmp    SM_PageRead		; Cmd: Read1
SM_RD_Page: 					; Read a page and set pointer to offset 0
		ldi	R16,SM_ReadLowHalf	; Cmd: Read
SM_PageRead:
		in	R3,SREG			; Save I flag
		cli   				; Disable interrupts (TO AVOID DATA COLLAPTION)

		ldi	R17,SMIL_RM_WriteCmd
		sts	ADR_SMMODE,R17		; CE="L", Command Phase: CLE="H", ALE="L"
		nop
		sts	ADR_SMDATA,R16		; Command

		ldi	R16,SMIL_RM_WriteAddr   ; Address Phase: CLE="L", ALE="H"
		sts	ADR_SMMODE,R16

		sts	ADR_SMDATA,R10		; Addr 0
		sts	ADR_SMDATA,R11		; Addr 1  _PageL
		sts	ADR_SMDATA,R12		; Addr 1  _PageM
		sts	ADR_SMDATA,R13          ; Addr 3  _PageH (will be ignored at < 64M media)

		ldi	R16,SMIL_RM_ReadData
		sts	ADR_SMMODE,R16		;Data Phase: CLE="L", ALE="L"  CE="L"

		out	SREG,R3			;Restore I flag
		push	XL			;itt varni kell max 10us-t
		push	XH
		ldi	XL,low(W10us/9)
		ldi	XH,high(W10us/9)
SMPRd:
		sbiw	XL,1			;[2]
		breq	SMRdTout		;[1]
		lds	R16,ADR_SMSTAT	 	;[3, external sram]
		sbrs	R16,7		 	;[1] Wait for R/B pin
		  rjmp	SMPRd		 	;[2], = total 9 cycles
		pop	XH
		pop	XL
		clc
		ret
SMRdTout:
		pop	XH
		pop	XL
		sec
		ret



;***************************************************************************
; SM_EvenParityGen
; SM - logical to physical block address parity generator (logical cluster)
;
; In:   R1:R0 - Block (Cluster) address
; Out:
;	R17 - 0,1 Parity
; Alt: R2,R3,R16
;
SM_EvenParityGen:
		mov	R2,R0
		mov	R3,R1
		clr	R17
		ldi	R16,16
EPG01:		ror	R3
		ror	R2
		brcc	EPG02
		inc	R17
EPG02:		dec	R16
		brne	EPG01
		andi	R17,1
		ret

;***************************************************************************
; SM_SearchCluster
; SM - search Block Address 0x1001 == 0 Cluster
;
; In:   R11:R10 - Cluster   16Mb - 0..998
; Out:
;	R13:R12:R11:R10 - Physical Address of Logical Cluster
;       c = 0 successfull, SmartMedia nyitva marad
;	c = 1 Error, Smartmediat lezarja
;
SM_SearchCluster:
		mov	R0,R10
		mov	R1,R11
		lsl	R0
		rol	R1
		ldi	R16,0x10
		or	R1,R16
		rcall	SM_EvenParityGen
		or	R0,R17			;R1:R0 Block Address

		lds	XL,SmBlocks+0
		lds	XH,SmBlocks+1		;ennyi Blockot kell atvizsgalni
		lds	R14,SmPPB		;Pages per block
		ldi	R16,6
		mov	R10,R16			;block address offset R10 = 6
	       	clr	R11
		clr	R12
		clr	R13			;sector counter
		clr	R5			;legyen 0
SM_SSec:
		rcall	SM_RD_Page2		;belapozzuk ezt a lapot (sectort), mindig a cluster elso sectora
		brcs	SMSSError

		lds	R16,ADR_SMDATA		;Hi-byte of Block Address
		mov	R4,R16
		lds	R16,ADR_SMDATA		;low-byte of Block Address
		cp	R16,R0
		cpc	R4,R1
		breq	BlockMegvan

		add	R11,R14
		adc	R12,R5
		adc	R13,R5
		sbiw	XL,1
		brne	SM_SSec
SMSSError:
		ldi	R16,SMIL_Standby
		sts	ADR_SMMODE,R16			; CE = "H"
		sec
		ret
BlockMegvan:
		clr	R10
		clc
		ret


;***************************************************************************
; SM_SearchSector
; SM - search Sector , Zero Base
;
; In:   R12:R11:R10 - Sector
; Out:
;	R13:R12:R11:R10 - Physical Address of Logical Sector
;	R16 - toredek szektor szama (Cluster vegeig)
;       c = 0 successfull, SmartMedia nyitva marad
;	c = 1 Error, Smartmediat lezarja
;	SMCE = L (open)
;
; Alt:  R0, R1, R2, R3, R5, R8, R14, R16, R17, XL, XH
; Csak 32 sector(page)/block(cluster) tipusu kartyakra jo!!!!!
;
SM_SearchSector:
		mov	R8,R10
		ldi	R16,5
SMSSec1:
		lsr	R12
		ror	R11
		ror	R10
		dec	R16
		brne	SMSSec1		;elosztva 32-vel

		rcall	SM_SearchCluster
		brcs	SMSSecErr
		mov	R16,R8
		clr	R10
		andi	R16,31		;toredek szektor
		add	R11,R16
		adc	R12,R10
		adc	R13,R10
		neg	R16
		andi	R16,31
		clc
		ret
SMSSecErr:
		sec
		ret


