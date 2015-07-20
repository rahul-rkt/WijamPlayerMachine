#define AnimateArrayLength 10
#define RegLength 5
#define GridSize 6
#define AdvancePlayerSideMargin 30
#define LabelMargin 10

//note Size = 22 means there are 3 octives within one page in the simple mode
#define noteSize 22

//#define TEST
#ifdef TEST
#   define DSLog(...) NSLog(__VA_ARGS__)
#else
#   define DSLog(...)
#endif

// define VIEWTEST to skip the connection part
// #define VIEWTEST

#ifdef DEBUG
#   define NSLog(...) NSLog(__VA_ARGS__)
#else
#   define NSLog(...)
#endif
