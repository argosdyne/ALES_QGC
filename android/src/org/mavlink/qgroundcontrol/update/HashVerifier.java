package org.mavlink.qgroundcontrol.update;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileReader;
import java.io.IOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

public final class HashVerifier {
    private HashVerifier() { }

    public static String computeSha256(File file) throws IOException {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            FileInputStream input = new FileInputStream(file);
            try {
                byte[] buffer = new byte[65536];
                int count;
                while ((count = input.read(buffer)) >= 0) {
                    digest.update(buffer, 0, count);
                }
            } finally {
                input.close();
            }
            return toHex(digest.digest());
        } catch (NoSuchAlgorithmException e) {
            throw new IOException("SHA-256 is not available", e);
        }
    }

    public static String readExpectedSha256(File sha256File) throws IOException {
        BufferedReader reader = new BufferedReader(new FileReader(sha256File));
        try {
            String line = reader.readLine();
            if (line == null) {
                throw new IOException("Hash file is empty");
            }
            String trimmed = line.trim().toLowerCase(java.util.Locale.US);
            if (trimmed.startsWith("sha256(")) {
                int index = trimmed.lastIndexOf('=');
                if (index >= 0 && index + 1 < trimmed.length()) {
                    trimmed = trimmed.substring(index + 1).trim();
                }
            } else {
                int space = trimmed.indexOf(' ');
                if (space > 0) {
                    trimmed = trimmed.substring(0, space);
                }
            }
            if (!trimmed.matches("[0-9a-f]{64}")) {
                throw new IOException("Hash file does not contain a SHA-256 hex value");
            }
            return trimmed;
        } finally {
            reader.close();
        }
    }

    public static boolean constantTimeEquals(String expected, String actual) {
        if (expected == null || actual == null) {
            return false;
        }
        byte[] expectedBytes = expected.getBytes();
        byte[] actualBytes = actual.getBytes();
        return MessageDigest.isEqual(expectedBytes, actualBytes);
    }

    private static String toHex(byte[] bytes) {
        StringBuilder builder = new StringBuilder(bytes.length * 2);
        for (int i = 0; i < bytes.length; i++) {
            builder.append(String.format("%02x", bytes[i] & 0xff));
        }
        return builder.toString();
    }
}
