package com.cxy.workbench;
import android.content.*;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import java.io.*;

/** Non-exported, URI-granted access to one validated private cache APK only. */
public final class UpdateProvider extends ContentProvider {
 public boolean onCreate(){return true;}
 private File checked(Uri uri)throws FileNotFoundException{if(!getContext().getPackageName().concat(".updates").equals(uri.getAuthority())||!"/workbench-update.apk".equals(uri.getPath())||uri.getQuery()!=null||uri.getFragment()!=null)throw new FileNotFoundException("Invalid update URI");File f=AppUpdater.file(getContext());if(!f.isFile())throw new FileNotFoundException("Update not cached");return f;}
 public String getType(Uri uri){try{checked(uri);}catch(FileNotFoundException e){throw new IllegalArgumentException("Invalid update URI");}return "application/vnd.android.package-archive";}
 public ParcelFileDescriptor openFile(Uri uri,String mode)throws FileNotFoundException{if(!"r".equals(mode))throw new FileNotFoundException("Read only");return ParcelFileDescriptor.open(checked(uri),ParcelFileDescriptor.MODE_READ_ONLY);}
 public Cursor query(Uri u,String[] projection,String selection,String[] args,String order){try{File f=checked(u);String[] cols=projection==null?new String[]{OpenableColumns.DISPLAY_NAME,OpenableColumns.SIZE}:projection;MatrixCursor c=new MatrixCursor(cols);Object[] row=new Object[cols.length];for(int n=0;n<cols.length;n++){if(OpenableColumns.DISPLAY_NAME.equals(cols[n]))row[n]="CXY-工作台-更新.apk";else if(OpenableColumns.SIZE.equals(cols[n]))row[n]=f.length();}c.addRow(row);return c;}catch(FileNotFoundException e){throw new IllegalArgumentException("Invalid update URI");}}
 public Uri insert(Uri u,ContentValues v){throw new UnsupportedOperationException("Read only");}public int delete(Uri u,String s,String[] a){throw new UnsupportedOperationException("Read only");}public int update(Uri u,ContentValues v,String s,String[] a){throw new UnsupportedOperationException("Read only");}
}
