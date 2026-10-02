/* Experimental live microphone bridge for DraStic r2.5.2.2 AArch64.
 * This targets build ID 7a5e0e5fc6e52e6e8f5499c3d4d667ef51db0748.
 * DraStic is proprietary; the hook changes one internal function at runtime.
 */
typedef __UINT8_TYPE__ uint8_t;
typedef __UINT16_TYPE__ uint16_t;
typedef __INT16_TYPE__ int16_t;
typedef __UINT32_TYPE__ uint32_t;
typedef __INT32_TYPE__ int32_t;
typedef __UINT64_TYPE__ uint64_t;
typedef __INT64_TYPE__ int64_t;
typedef __UINTPTR_TYPE__ uintptr_t;
typedef __SIZE_TYPE__ size_t;

typedef struct _IO_FILE FILE;
extern FILE *stderr;
extern FILE *fopen(const char *, const char *);
extern char *fgets(char *, int, FILE *);
extern int fclose(FILE *);
extern int sscanf(const char *, const char *, ...);
extern char *strstr(const char *, const char *);
extern int fprintf(FILE *, const char *, ...);
extern void *dlsym(void *, const char *);
extern int mprotect(void *, size_t, int);

typedef unsigned int SDL_AudioDeviceID;
typedef struct {
    int freq;
    uint16_t format;
    uint8_t channels;
    uint8_t silence;
    uint16_t samples;
    uint16_t padding;
    uint32_t size;
    void (*callback)(void *, uint8_t *, int);
    void *userdata;
} SDL_AudioSpec;

extern uint32_t SDL_WasInit(uint32_t);
extern int SDL_InitSubSystem(uint32_t);
extern SDL_AudioDeviceID SDL_OpenAudioDevice(const char *, int,
                                              const SDL_AudioSpec *, SDL_AudioSpec *, int);
extern void SDL_PauseAudioDevice(SDL_AudioDeviceID, int);

#define SDL_INIT_AUDIO 0x10u
#define AUDIO_S16SYS 0x8010u
#define RING_SIZE 32768u
#define RING_MASK (RING_SIZE - 1u)

static int16_t ring[RING_SIZE];
static uint32_t write_pos;
static uint32_t read_pos;
static uint32_t capture_rate = 48000;
static uint32_t capture_phase;
static int64_t dc_q16;
static SDL_AudioDeviceID capture_device;
static int capture_tried;
static int patch_ok;
static int patch_tried;
static void install_hook(void);

/* DraStic calls this at its emulated microphone sample rate. */
static int live_microphone_sample(void *spu, uint64_t cycles)
{
    (void)spu;
    (void)cycles;
    uint32_t read = __atomic_load_n(&read_pos, __ATOMIC_RELAXED);
    uint32_t write = __atomic_load_n(&write_pos, __ATOMIC_ACQUIRE);
    if (read == write)
        return 0;
    /* Keep less than a quarter second queued after a period without mic reads. */
    if (write - read > 2048u)
        read = write - 512u;
    int16_t sample = ring[read & RING_MASK];
    __atomic_store_n(&read_pos, read + 1, __ATOMIC_RELEASE);
    return sample;
}

static void capture_callback(void *userdata, uint8_t *stream, int len)
{
    (void)userdata;
    const int16_t *samples = (const int16_t *)stream;
    uint32_t count = (uint32_t)len / 2u;
    for (uint32_t i = 0; i < count; ++i) {
        int32_t input = samples[i];
        dc_q16 += (((int64_t)input * 65536) - dc_q16) >> 14;
        int32_t clean = (input - (int32_t)(dc_q16 >> 16)) * 2;
        if (clean > 32767) clean = 32767;
        if (clean < -32768) clean = -32768;
        capture_phase += 16384u;
        if (capture_phase < capture_rate)
            continue;
        capture_phase -= capture_rate;
        uint32_t write = __atomic_load_n(&write_pos, __ATOMIC_RELAXED);
        ring[write & RING_MASK] = (int16_t)clean;
        __atomic_store_n(&write_pos, write + 1, __ATOMIC_RELEASE);
    }
}

static void start_capture(void)
{
    if (capture_tried || !patch_ok)
        return;
    capture_tried = 1;
    if (!SDL_WasInit(SDL_INIT_AUDIO) && SDL_InitSubSystem(SDL_INIT_AUDIO) != 0) {
        fprintf(stderr, "drastic-live-mic: SDL audio initialization failed\n");
        return;
    }

    SDL_AudioSpec desired = {0}, obtained = {0};
    desired.freq = 48000;
    desired.format = AUDIO_S16SYS;
    desired.channels = 1;
    desired.samples = 256;
    desired.callback = capture_callback;
    capture_device = SDL_OpenAudioDevice("Built-in Audio Microphone", 1,
                                        &desired, &obtained, 0);
    if (!capture_device) {
        fprintf(stderr, "drastic-live-mic: could not open Built-in Audio Microphone\n");
        return;
    }
    capture_rate = (uint32_t)obtained.freq;
    SDL_PauseAudioDevice(capture_device, 0);
    fprintf(stderr, "drastic-live-mic: capture active at %u Hz\n", capture_rate);
}

int SDL_PollEvent(void *event)
{
    static int (*next_poll)(void *);
    if (!next_poll)
        next_poll = (int (*)(void *))dlsym((void *)-1, "SDL_PollEvent");
    if (!patch_tried) {
        patch_tried = 1;
        install_hook();
    }
    start_capture();
    return next_poll(event);
}

static void flush_instruction_cache(uintptr_t address)
{
    __asm__ volatile("dc cvau, %0" :: "r"(address) : "memory");
    __asm__ volatile("dsb ish" ::: "memory");
    __asm__ volatile("ic ivau, %0" :: "r"(address) : "memory");
    __asm__ volatile("dsb ish" ::: "memory");
    __asm__ volatile("isb" ::: "memory");
}

static void install_hook(void)
{
    FILE *maps = fopen("/proc/self/maps", "r");
    if (!maps)
        return;
    char line[1024];
    uintptr_t base = 0;
    while (fgets(line, sizeof(line), maps)) {
        if (!strstr(line, "/drastic.bin"))
            continue;
        unsigned long start = 0, end = 0, offset = 0;
        char perms[8];
        if (sscanf(line, "%lx-%lx %7s %lx", &start, &end, perms, &offset) == 4
            && offset == 0) {
            base = (uintptr_t)start;
            break;
        }
    }
    fclose(maps);
    if (!base) {
        fprintf(stderr, "drastic-live-mic: DraStic mapping not found\n");
        return;
    }

    uint32_t *target = (uint32_t *)(base + 0x6c7a0u);
    const uint32_t expected[4] = { 0x91410002u, 0x39750043u,
                                   0x340003a3u, 0xf9469844u };
    for (int i = 0; i < 4; ++i) {
        if (target[i] != expected[i]) {
            fprintf(stderr, "drastic-live-mic: unsupported DraStic binary\n");
            return;
        }
    }

    uintptr_t page = (uintptr_t)target & ~(uintptr_t)4095u;
    if (mprotect((void *)page, 4096, 7) != 0) {
        fprintf(stderr, "drastic-live-mic: code patch denied\n");
        return;
    }
    /* ldr x16, #8; br x16; .quad live_microphone_sample */
    target[0] = 0x58000050u;
    target[1] = 0xd61f0200u;
    *(uint64_t *)(target + 2) = (uint64_t)(uintptr_t)live_microphone_sample;
    flush_instruction_cache((uintptr_t)target);
    mprotect((void *)page, 4096, 5);
    patch_ok = 1;
    fprintf(stderr, "drastic-live-mic: SPU microphone hook installed\n");
}
