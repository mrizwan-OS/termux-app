# Development Guide - Termux App

This guide covers setting up a development environment and contributing to the Termux App project.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Building](#building)
- [Testing](#testing)
- [Code Quality](#code-quality)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required
- **Java Development Kit (JDK) 11+**
  - Download from [Oracle](https://www.oracle.com/java/technologies/downloads/#java11) or [OpenJDK](https://openjdk.java.net/)
  - Verify: `java -version`

- **Gradle** (included via wrapper)
  - Verify: `./gradlew --version`

### Optional but Recommended
- **Android SDK** (if building for Android)
- **Git** for version control
- **IDE**: Android Studio, IntelliJ IDEA, or VS Code

## Initial Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/mrizwan-OS/termux-app.git
   cd termux-app
   ```

2. **Set up environment variables** (if needed):
   ```bash
   export JAVA_HOME=/path/to/jdk
   export PATH=$JAVA_HOME/bin:$PATH
   ```

3. **Verify setup**:
   ```bash
   ./gradlew --version
   java -version
   ```

## Building

### Full Build
```bash
./gradlew build
```

### Build with Skip Tests
```bash
./gradlew build -x test
```

### Build Specific Module
```bash
./gradlew :app:build
./gradlew :terminal-emulator:build
```

### Clean Build
```bash
./gradlew clean build
```

## Testing

### Run All Tests
```bash
./gradlew test
```

### Run Specific Test Class
```bash
./gradlew test --tests com.example.TerminalTest
```

### Run Tests with Coverage
```bash
./gradlew test jacocoTestReport
```

### View Test Report
```bash
# After running tests, open:
# ./build/reports/tests/test/index.html
```

## Code Quality

### Linting
```bash
./gradlew lint
```

### Static Analysis
```bash
./gradlew check
```

### Code Formatting
```bash
./gradlew spotlessApply
```

### Check Code Format (without applying)
```bash
./gradlew spotlessCheck
```

### Full Analysis Report
```bash
./gradlew build --info
```

## Deployment

### Create Debug APK
```bash
./gradlew assembleDebug
# Output: app/build/outputs/apk/debug/app-debug.apk
```

### Create Release APK
```bash
./gradlew assembleRelease
# Output: app/build/outputs/apk/release/app-release.apk
```

### Install on Connected Device
```bash
./gradlew installDebug
```

### Run on Emulator
```bash
./gradlew installDebug
adb shell am start -n com.termux/.MainActivity
```

## Project Structure

```
termux-app/
├── app/                    # Main Android application module
├── terminal-emulator/      # Terminal emulator implementation
├── terminal-view/          # UI components for terminal
├── termux-shared/          # Shared utilities and constants
├── build.gradle            # Root build configuration
├── gradle/                 # Gradle wrapper and configuration
├── docs/                   # Documentation files
└── scripts/                # Build and utility scripts
```

## Common Issues and Solutions

### Issue: Gradle Build Fails with Memory Error
**Solution**: Increase Gradle heap size in `gradle.properties`:
```properties
org.gradle.jvmargs=-Xmx4096m -XX:MaxPermSize=512m
```

### Issue: Java Version Mismatch
**Solution**: Ensure JDK 11+ is used:
```bash
./gradlew --version  # Shows Gradle version and Java version used
java -version        # Shows system Java version
```

### Issue: Tests Fail Locally but Pass in CI
**Solution**: 
- Run tests with verbose output: `./gradlew test --info`
- Check test logs: `cat build/test-results/test/`
- Run with specific Java version: `JAVA_HOME=/path/to/jdk ./gradlew test`

### Issue: Build Files Not Found
**Solution**: Clean and rebuild:
```bash
./gradlew clean
./gradlew build
```

## Git Workflow

### Feature Branch
```bash
git checkout -b feature/your-feature-name
# Make changes, test, commit
git push origin feature/your-feature-name
# Create Pull Request
```

### Commit Message Format
```
type(scope): subject

body

footer
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

**Example**:
```
feat(terminal): add support for ANSI color codes

- Implemented ANSI color parsing
- Added color configuration UI
- Updated tests to cover new functionality

Closes #42
```

## Continuous Integration

The project uses GitHub Actions for CI/CD. Workflows are triggered on:
- Push to master/main/develop
- Pull requests
- Manual workflow dispatch

View status at: `.github/workflows/`

## Performance Tips

- Use `--parallel` flag for faster builds: `./gradlew build --parallel`
- Enable build cache: Already enabled by default
- Skip tests during development: `./gradlew build -x test`
- Use incremental compilation: Set in `gradle.properties`

## Debugging

### Enable Debug Logging
```bash
./gradlew build --debug
```

### Remote Debugging (Android Studio)
1. Run app in debug mode
2. Set breakpoints in IDE
3. Debugger will attach automatically

### Logcat Monitoring
```bash
adb logcat | grep termux
```

## Documentation

- API Documentation: Generate with `./gradlew javadoc`
- Markdown Docs: Located in `docs/` directory
- Code Comments: Use JavaDoc format for public APIs

## Need Help?

- Check [Contributing Guidelines](.github/CONTRIBUTING.md)
- Review existing [Issues](https://github.com/mrizwan-OS/termux-app/issues)
- Create a new [Issue](https://github.com/mrizwan-OS/termux-app/issues/new)

---

Happy coding! 🚀
